
defmodule M4w.Ops.AgentRunner do
  @moduledoc """
  Periodically picks up `M4w.Ops.Item`s sitting in `state: "waiting"` inside
  a Room worked by an `ai` Entity, and runs them through the configured
  `M4w.Ops.AgentExecutor`.

  Modeled on `M4w.Mail.StalwartPoller`: self-schedules via
  `Process.send_after/3`, never crashes on a failed item (logs and keeps
  polling), and only talks to the domain through `M4w.Ops` — never Repo
  directly.

  Only started when `:agent_runner, :enabled` is truthy — see
  `M4w.Application`. Disabled in `:test` so this background process never
  reaches into a test's Ecto Sandbox connection it doesn't own.
  """

  use GenServer

  require Logger

  alias M4w.Ops
  alias M4w.Ops.Space

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    config = Application.get_env(:m4w, :agent_runner, [])

    state = %{
      poll_interval_ms: Keyword.get(config, :poll_interval_ms, 5_000),
      executor: Keyword.get(config, :executor, M4w.Ops.AgentExecutor.Stub)
    }

    send(self(), :poll)
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    poll(state.executor)
    Process.send_after(self(), :poll, state.poll_interval_ms)
    {:noreply, state}
  end

  defp poll(executor) do
    Ops.list_ai_runnable_items()
    |> Enum.each(&run_item(&1, executor))
  rescue
    error ->
      Logger.error("AgentRunner: poll failed: #{Exception.format(:error, error, __STACKTRACE__)}")
  end

  defp run_item(item, executor) do
    case Ops.update_item(item, %{"state" => "running"}) do
      {:ok, running_item} ->
        execute(running_item, executor)

      {:error, changeset} ->
        Logger.error("AgentRunner: item #{item.id} could not start: #{inspect(changeset)}")
    end
  rescue
    error ->
      Logger.error(
        "AgentRunner: item #{item.id} crashed: #{Exception.format(:error, error, __STACKTRACE__)}"
      )
  end

  defp execute(item, executor) do
    case executor.run(item) do
      {:ok, result} ->
        log_passage(item, "Agent slutförde ärendet: #{result.summary}")
        Ops.update_item(item, %{"state" => "done"})

      {:error, reason} ->
        log_passage(item, "Agent misslyckades: #{inspect(reason)}")
        Ops.update_item(item, %{"state" => "amber"})
    end
  end

  defp log_passage(item, text) do
    Ops.create_passage(%Space{id: item.room.space_id}, %{"item_id" => item.id, "text" => text})
  end
end
