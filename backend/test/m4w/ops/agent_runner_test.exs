defmodule M4w.Ops.AgentRunnerTest do
  use ExUnit.Case, async: true

  alias M4w.Ops.AgentExecutor.Stub
  alias M4w.Ops.{AgentRunner, Entity, Item, Room}

  defmodule FakeClaudeCodeExecutor do
    @behaviour M4w.Ops.AgentExecutor

    @impl true
    def run(_item), do: {:ok, %{summary: "fake"}}
  end

  defp item_with_entities(entities) do
    %Item{room: %Room{entities: entities}}
  end

  defp state(overrides \\ %{}) do
    Map.merge(
      %{executors: %{"claude_code" => FakeClaudeCodeExecutor}, default_executor: Stub},
      overrides
    )
  end

  describe "select_executor/2" do
    test "picks the executor mapped to the primary ai entity's agent_type" do
      item = item_with_entities([%Entity{kind: "ai", agent_type: "claude_code"}])

      assert AgentRunner.select_executor(item, state()) == FakeClaudeCodeExecutor
    end

    test "falls back to the default executor when agent_type has no mapping" do
      item = item_with_entities([%Entity{kind: "ai", agent_type: "unknown"}])

      assert AgentRunner.select_executor(item, state()) == Stub
    end

    test "falls back to the default executor when the room has no ai entity" do
      item = item_with_entities([%Entity{kind: "human", agent_type: nil}])

      assert AgentRunner.select_executor(item, state()) == Stub
    end

    test "ignores human entities and picks the first ai entity" do
      item =
        item_with_entities([
          %Entity{kind: "human", agent_type: nil},
          %Entity{kind: "ai", agent_type: "claude_code"}
        ])

      assert AgentRunner.select_executor(item, state()) == FakeClaudeCodeExecutor
    end
  end
end
