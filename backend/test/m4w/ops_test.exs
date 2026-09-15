defmodule M4w.OpsTest do
  use M4w.DataCase, async: true

  alias M4w.Design.Providers.Stub
  alias M4w.Ops
  alias M4w.Ops.{Mail, Space}
  alias M4w.Repo

  defp space_fixture(attrs \\ %{}) do
    %Space{}
    |> Space.changeset(
      Map.merge(
        %{
          name: "Styrelsearbete",
          address: "styrelse-#{System.unique_integer([:positive])}@m4w.test"
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp mail_fixture(space, attrs \\ %{}) do
    %Mail{}
    |> Mail.changeset(
      Map.merge(
        %{
          space_id: space.id,
          from: "Avsändare",
          subject: "Ärende #{System.unique_integer([:positive])}",
          body: ["Innehåll."],
          occurred_at: DateTime.utc_now() |> DateTime.truncate(:second),
          purpose: "inbox",
          status: "routed"
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  describe "generate_rooms/2" do
    test "returns persisted rooms unchanged when the space already has them" do
      space = space_fixture()
      {:ok, room} = Ops.create_room(space, %{"name" => "Befintligt rum"})

      assert Ops.generate_rooms(space) == [room]
    end

    test "designs a fresh room pipeline via the configured provider when there are none" do
      space = space_fixture(%{goal: "Driv styrelsearbete från kallelse till protokoll"})

      drafts = Ops.generate_rooms(space, provider: Stub)

      assert Enum.map(drafts, & &1.name) == ["Inkorg", "Behandling"]
      assert Enum.map(drafts, & &1.temp_id) == ["-1", "-2"]
      assert Enum.map(drafts, & &1.position) == [0, 1]
      assert Enum.all?(drafts, &(&1.entity_kind in ["ai", "human", "mixed"]))
    end

    test "falls back to the fixed template when the provider fails" do
      space = space_fixture()

      drafts = Ops.generate_rooms(space, provider: M4w.OpsTest.FailingProvider)

      assert Enum.map(drafts, & &1.name) == ["Inkorg", "Behandling", "Godkännande", "Klart"]
    end

    test "logs the generation attributed to the ops space" do
      space = space_fixture()

      Ops.generate_rooms(space, provider: Stub)

      assert [generation] = M4w.Design.list_ops_space_generations(space.id)
      assert generation.provider == "stub"
      assert generation.status == "ok"
    end

    test "includes mail marked use: true as generation context" do
      space = space_fixture()

      Repo.insert!(
        Mail.changeset(%Mail{}, %{
          space_id: space.id,
          from: "Ordförande",
          subject: "Kallelse Q3",
          body: ["Bifogar dagordning för Q3-mötet."],
          occurred_at: DateTime.utc_now() |> DateTime.truncate(:second),
          purpose: "inbox",
          status: "routed",
          use: true
        })
      )

      Process.register(self(), :ops_test_spy)
      Ops.generate_rooms(space, provider: M4w.OpsTest.SpyProvider)

      assert_receive {:design_request, request}
      assert request.user_prompt =~ "Kallelse Q3"
      assert request.user_prompt =~ "Bifogar dagordning"
    end
  end

  describe "run_replay/2" do
    test "persists a real classification from the configured provider" do
      space = space_fixture()
      {:ok, room} = Ops.create_room(space, %{"name" => "Behandling"})
      mail = mail_fixture(space)

      [result] = Ops.run_replay(space, [mail.id], provider: M4w.OpsTest.ClassifyProvider)

      assert result.replay_room_id == room.id
      assert result.replay_confidence == 87
      assert result.replay_key == "OSA klar"
      assert result.replay_uncertain == false
    end

    test "does not call the provider or touch mail when the space has no rooms yet" do
      space = space_fixture()
      mail = mail_fixture(space)

      Process.register(self(), :ops_test_spy)
      [result] = Ops.run_replay(space, [mail.id], provider: M4w.OpsTest.SpyProvider)

      refute_received {:design_request, _}
      assert result.replay_room_id == nil
      assert result.replay_confidence == nil
    end

    test "leaves mail untouched when the provider fails" do
      space = space_fixture()
      {:ok, _room} = Ops.create_room(space, %{"name" => "Behandling"})
      mail = mail_fixture(space)

      [result] = Ops.run_replay(space, [mail.id], provider: M4w.OpsTest.FailingProvider)

      assert result.replay_room_id == nil
      assert result.replay_uncertain == false
    end

    test "leaves mails the provider didn't return an assignment for untouched" do
      space = space_fixture()
      {:ok, _room} = Ops.create_room(space, %{"name" => "Behandling"})
      assigned_mail = mail_fixture(space)
      unassigned_mail = mail_fixture(space)

      results =
        Ops.run_replay(space, [assigned_mail.id, unassigned_mail.id],
          provider: M4w.OpsTest.PartialClassifyProvider
        )

      assigned = Enum.find(results, &(&1.id == assigned_mail.id))
      unassigned = Enum.find(results, &(&1.id == unassigned_mail.id))

      assert assigned.replay_room_id != nil
      assert unassigned.replay_room_id == nil
    end
  end

  describe "entities" do
    test "create_room creates a default claude_code entity from a legacy entity param" do
      space = space_fixture()

      {:ok, room} =
        Ops.create_room(space, %{"name" => "Rum", "entity" => %{"kind" => "ai", "label" => "AI"}})

      assert [entity] = Ops.list_room_entities(room)
      assert entity.kind == "ai"
      assert entity.agent_type == "claude_code"
      assert entity.name == "AI"
    end

    test "create_room creates an ai and a human entity for a legacy mixed entity param" do
      space = space_fixture()

      {:ok, room} =
        Ops.create_room(space, %{
          "name" => "Rum",
          "entity" => %{"kind" => "mixed", "label" => "Team"}
        })

      entities = Ops.list_room_entities(room)
      assert Enum.map(entities, & &1.kind) |> Enum.sort() == ["ai", "human"]
      assert Enum.all?(entities, &(&1.name == "Team"))
    end

    test "update_room updates the existing primary entity's label instead of duplicating it" do
      space = space_fixture()

      {:ok, room} =
        Ops.create_room(space, %{"name" => "Rum", "entity" => %{"kind" => "ai", "label" => "AI"}})

      {:ok, room} =
        Ops.update_room(room, %{"entity" => %{"kind" => "ai", "label" => "Ny etikett"}})

      assert [entity] = Ops.list_room_entities(room)
      assert entity.name == "Ny etikett"
    end

    test "create_entity, update_entity and delete_entity manage entities directly" do
      space = space_fixture()
      {:ok, room} = Ops.create_room(space, %{"name" => "Rum"})

      {:ok, entity} =
        Ops.create_entity(room, %{
          "name" => "Claude",
          "kind" => "ai",
          "agent_type" => "claude_code"
        })

      assert Ops.list_room_entities(room) == [entity]

      {:ok, entity} = Ops.update_entity(entity, %{"state" => "working"})
      assert entity.state == "working"

      {:ok, _} = Ops.delete_entity(entity)
      assert Ops.list_room_entities(room) == []
    end
  end

  describe "list_ai_runnable_items/1" do
    test "returns waiting items in rooms worked by an ai entity" do
      space = space_fixture()
      {:ok, room} = Ops.create_room(space, %{"name" => "Rum"})

      {:ok, _entity} =
        Ops.create_entity(room, %{
          "name" => "Claude",
          "kind" => "ai",
          "agent_type" => "claude_code"
        })

      {:ok, item} = Ops.create_item(room, %{"title" => "Ärende"})

      assert [runnable] = Ops.list_ai_runnable_items()
      assert runnable.id == item.id
      assert runnable.room.id == room.id
    end

    test "excludes items in rooms with only a human entity" do
      space = space_fixture()
      {:ok, room} = Ops.create_room(space, %{"name" => "Rum"})
      {:ok, _entity} = Ops.create_entity(room, %{"name" => "Person", "kind" => "human"})
      {:ok, _item} = Ops.create_item(room, %{"title" => "Ärende"})

      assert Ops.list_ai_runnable_items() == []
    end

    test "excludes items that are not waiting" do
      space = space_fixture()
      {:ok, room} = Ops.create_room(space, %{"name" => "Rum"})

      {:ok, _entity} =
        Ops.create_entity(room, %{
          "name" => "Claude",
          "kind" => "ai",
          "agent_type" => "claude_code"
        })

      {:ok, item} = Ops.create_item(room, %{"title" => "Ärende"})
      {:ok, _item} = Ops.update_item(item, %{"state" => "done"})

      assert Ops.list_ai_runnable_items() == []
    end

    test "does not duplicate an item when its room has multiple ai entities" do
      space = space_fixture()
      {:ok, room} = Ops.create_room(space, %{"name" => "Rum"})

      {:ok, _claude} =
        Ops.create_entity(room, %{
          "name" => "Claude",
          "kind" => "ai",
          "agent_type" => "claude_code"
        })

      {:ok, _codex} =
        Ops.create_entity(room, %{"name" => "Codex", "kind" => "ai", "agent_type" => "codex"})

      {:ok, item} = Ops.create_item(room, %{"title" => "Ärende"})

      assert [runnable] = Ops.list_ai_runnable_items()
      assert runnable.id == item.id
    end
  end

  defmodule FailingProvider do
    @behaviour M4w.Design.Provider

    @impl true
    def name, do: "failing"

    @impl true
    def design(_request, _opts), do: {:error, :unavailable}
  end

  defmodule SpyProvider do
    @behaviour M4w.Design.Provider

    @impl true
    def name, do: "spy"

    @impl true
    def design(request, _opts) do
      send(:ops_test_spy, {:design_request, request})

      {:ok,
       %{
         blueprint: %{
           "rooms" => [
             %{
               "name" => "R",
               "subgoal" => "S",
               "entity_kind" => "ai",
               "entity_label" => "AI",
               "key" => "K"
             }
           ]
         },
         usage: %{input_tokens: 1, output_tokens: 1}
       }}
    end
  end

  defmodule ClassifyProvider do
    @behaviour M4w.Design.Provider

    @impl true
    def name, do: "classify-test"

    @impl true
    def design(%{schema: schema}, _opts) do
      properties = schema["properties"]["assignments"]["items"]["properties"]
      [mail_id | _] = properties["mail_id"]["enum"]
      [room_name | _] = properties["room"]["enum"]

      {:ok,
       %{
         blueprint: %{
           "assignments" => [
             %{
               "mail_id" => mail_id,
               "room" => room_name,
               "confidence" => 87,
               "key" => "OSA klar",
               "uncertain" => false
             }
           ]
         },
         usage: %{input_tokens: 5, output_tokens: 5}
       }}
    end
  end

  defmodule PartialClassifyProvider do
    @behaviour M4w.Design.Provider

    @impl true
    def name, do: "partial-classify-test"

    @impl true
    def design(%{schema: schema}, _opts) do
      properties = schema["properties"]["assignments"]["items"]["properties"]
      [mail_id | _] = properties["mail_id"]["enum"]
      [room_name | _] = properties["room"]["enum"]

      {:ok,
       %{
         blueprint: %{
           "assignments" => [
             %{
               "mail_id" => mail_id,
               "room" => room_name,
               "confidence" => 60,
               "uncertain" => false
             }
           ]
         },
         usage: %{input_tokens: 5, output_tokens: 5}
       }}
    end
  end
end
