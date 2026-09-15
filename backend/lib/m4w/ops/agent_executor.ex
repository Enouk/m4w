defmodule M4w.Ops.AgentExecutor do
  @moduledoc """
  Behaviour implemented by whatever actually performs the work for an
  `M4w.Ops.Item` sitting in a Room worked by an `ai` Entity.

  `M4w.Ops.AgentRunner` calls the configured executor
  (`Application.get_env(:m4w, :agent_runner)[:executor]`) for each runnable
  Item it picks up. `M4w.Ops.AgentExecutor.Stub` is the only implementation
  today — real `claude_code`/`codex` CLI adapters (keyed off
  `Entity.agent_type`) are a later step.
  """

  alias M4w.Ops.Item

  @type result :: %{summary: String.t()}

  @callback run(Item.t()) :: {:ok, result()} | {:error, term()}
end
