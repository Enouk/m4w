defmodule M4w.DesignTest do
  use M4w.DataCase, async: true

  alias M4w.Design
  alias M4w.Design.Generation
  alias M4w.Design.Providers.Stub

  @space_request %{
    system_prompt: "system",
    user_prompt: "user",
    tool_name: "emit_space_blueprint",
    tool_description: "desc",
    schema: %{}
  }

  @room_request %{
    system_prompt: "system",
    user_prompt: "user",
    tool_name: "emit_room_blueprint",
    tool_description: "desc",
    schema: %{}
  }

  describe "generate_blueprint/2" do
    test "logs a successful generation attributed to a goal" do
      {:ok, goal} = M4w.World.create_goal(%{title: "Lansera en kundportal"})

      assert {:ok, blueprint, %Generation{} = generation} =
               Design.generate_blueprint(@space_request,
                 provider: Stub,
                 model: "claude-sonnet-5",
                 goal_id: goal.id
               )

      assert is_list(blueprint["rooms"])
      assert generation.goal_id == goal.id
      assert generation.ops_space_id == nil
      assert generation.provider == "stub"
      assert generation.status == "ok"
      assert generation.input_tokens == 120
      assert generation.output_tokens == 340
      # Stub has no pricing table entry by design — it never costs anything.
      assert Decimal.compare(generation.cost_usd, 0) == :eq
    end

    test "dispatches Stub to the room blueprint and logs it attributed to an ops space" do
      ops_space =
        %M4w.Ops.Space{}
        |> M4w.Ops.Space.changeset(%{name: "Styrelsearbete", address: "styrelse@m4w.test"})
        |> M4w.Repo.insert!()

      assert {:ok, blueprint, %Generation{} = generation} =
               Design.generate_blueprint(@room_request,
                 provider: Stub,
                 model: "claude-sonnet-5",
                 ops_space_id: ops_space.id
               )

      assert is_list(blueprint["rooms"])
      assert generation.goal_id == nil
      assert generation.ops_space_id == ops_space.id
    end

    test "logs a failed generation with zeroed usage and no cost" do
      {:ok, goal} = M4w.World.create_goal(%{title: "Ett mal"})

      assert {:error, {:boom, :nope}, %Generation{} = generation} =
               Design.generate_blueprint(@space_request,
                 provider: M4w.DesignTest.FailingProvider,
                 model: "claude-sonnet-5",
                 goal_id: goal.id
               )

      assert generation.status == "error"
      assert generation.error =~ "boom"
      assert generation.input_tokens == 0
      assert generation.output_tokens == 0
      assert Decimal.compare(generation.cost_usd, 0) == :eq
    end
  end

  describe "cost aggregation" do
    test "sums generations for a goal and a space" do
      {:ok, goal} = M4w.World.create_goal(%{title: "Spara pengar"})
      {:ok, space} = M4w.World.create_space(%{goal_id: goal.id, name: "Budget"})

      {:ok, _blueprint, generation} =
        Design.generate_blueprint(@space_request,
          provider: Stub,
          model: "claude-sonnet-5",
          goal_id: goal.id
        )

      {:ok, generation} = Design.attach_space(generation, space.id)

      assert Design.list_goal_generations(goal.id) == [generation]
      assert Design.total_cost_for_goal(goal.id) == generation.cost_usd
      assert Design.total_cost_for_space(space.id) |> Decimal.compare(generation.cost_usd) == :eq
    end

    test "returns zero cost when there are no generations" do
      assert Decimal.compare(Design.total_cost_for_goal(-1), 0) == :eq
      assert Decimal.compare(Design.total_cost_for_space(-1), 0) == :eq
      assert Decimal.compare(Design.total_cost_for_ops_space(-1), 0) == :eq
    end
  end

  defmodule FailingProvider do
    @behaviour M4w.Design.Provider

    @impl true
    def name, do: "failing"

    @impl true
    def design(_request, _opts), do: {:error, {:boom, :nope}}
  end
end
