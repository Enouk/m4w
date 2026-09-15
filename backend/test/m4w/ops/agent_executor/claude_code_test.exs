defmodule M4w.Ops.AgentExecutor.ClaudeCodeTest do
  use ExUnit.Case, async: true

  alias M4w.Ops.AgentExecutor.ClaudeCode
  alias M4w.Ops.{Item, Room, Space}

  defp item_fixture(attrs \\ %{}) do
    room =
      %Room{
        name: "Behandling",
        subgoal: "Ärendet berett",
        key: "öppnar när underlag är komplett",
        space: %Space{name: "Testutrymme", goal: "Bygg en liten hemsida"}
      }

    %Item{title: "Skapa index.html", meta: nil, room: room}
    |> Map.merge(attrs)
  end

  describe "build_prompt/1" do
    test "includes the space goal, room subgoal/key and item title" do
      prompt = ClaudeCode.build_prompt(item_fixture())

      assert prompt =~ "Bygg en liten hemsida"
      assert prompt =~ "Ärendet berett"
      assert prompt =~ "öppnar när underlag är komplett"
      assert prompt =~ "Skapa index.html"
    end

    test "includes item meta as extra detail when present" do
      prompt = ClaudeCode.build_prompt(item_fixture(%{meta: "Rubriken ska vara 'Hej'"}))

      assert prompt =~ "Rubriken ska vara 'Hej'"
    end

    test "omits a meta line entirely when meta is blank" do
      prompt = ClaudeCode.build_prompt(item_fixture(%{meta: nil}))

      refute prompt =~ "Detaljer:"
    end

    test "falls back to placeholder text for a blank space goal" do
      item = item_fixture()
      item = put_in(item.room.space.goal, "")

      prompt = ClaudeCode.build_prompt(item)

      assert prompt =~ "(inget angivet)"
    end
  end
end
