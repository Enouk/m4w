defmodule M4w.Ops.AgentExecutor.Stub do
  @moduledoc """
  Default `M4w.Ops.AgentExecutor` — does no real work, just confirms the
  Item was picked up. Placeholder until a real `claude_code`/`codex` CLI
  adapter is wired in.
  """

  @behaviour M4w.Ops.AgentExecutor

  @impl true
  def run(_item), do: {:ok, %{summary: "Stub-körning slutförd"}}
end
