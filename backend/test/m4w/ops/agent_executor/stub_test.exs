defmodule M4w.Ops.AgentExecutor.StubTest do
  use ExUnit.Case, async: true

  alias M4w.Ops.AgentExecutor.Stub
  alias M4w.Ops.Item

  test "run/1 always succeeds with a fixed summary, regardless of the item" do
    assert {:ok, %{summary: summary}} = Stub.run(%Item{id: 1, title: "Ärende"})
    assert is_binary(summary)
  end
end
