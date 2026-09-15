defmodule M4w.Ops.AgentExecutor.ClaudeCode do
  @moduledoc """
  Runs an Item through the host's Claude Code CLI non-interactively.

  The `claude` binary and the host's `~/.claude`/`~/.claude.json` session
  are bind-mounted read-only into the app container (see
  `docker-compose.yml`) so this reuses your already-authenticated CLI
  session instead of a fresh, API-key-based login. Because the container
  also carries `ANTHROPIC_API_KEY` (for `M4w.Design`), and Claude Code
  prefers an API key over a logged-in session when both are present, this
  module strips that env var from just the `claude` subprocess so the
  mounted session is what actually gets used.

  Runs with `--permission-mode bypassPermissions` — there's no human to
  approve tool calls in a background job, so this grants full,
  unsupervised file/shell access confined only to its working directory
  (see `workspace_dir/1`) and whatever else the container can reach. This
  is not a sandbox; see `M4w.Ops.AgentRunner`'s moduledoc for the accepted
  risk.

  Claude Code refuses to run with a permission-bypassing mode as root
  ("cannot be used with root/sudo privileges for security reasons") — and
  the app container's main process is root. So the CLI itself runs as the
  unprivileged `agentrunner` user (Dockerfile.dev, uid 1000) via `runuser`,
  invoked with an explicit argv list (never a shell string) so nothing in
  the prompt can be interpreted as shell syntax.
  """

  @behaviour M4w.Ops.AgentExecutor

  alias M4w.Ops.Item

  @run_as_user "agentrunner"

  @impl true
  def run(%Item{} = item) do
    workspace_dir = workspace_dir(item)
    File.mkdir_p!(workspace_dir)
    # `claude` runs as `@run_as_user`, not the root process creating this
    # directory — it needs write access to it.
    File.chmod!(workspace_dir, 0o777)

    task =
      Task.async(fn ->
        System.cmd(
          "runuser",
          [
            "-u",
            @run_as_user,
            "--",
            "claude",
            "-p",
            build_prompt(item),
            "--permission-mode",
            "bypassPermissions",
            "--output-format",
            "json"
          ],
          cd: workspace_dir,
          stderr_to_stdout: true,
          env: [{"ANTHROPIC_API_KEY", nil}]
        )
      end)

    case Task.yield(task, timeout_ms()) || Task.shutdown(task, :brutal_kill) do
      {:ok, {output, 0}} -> parse_result(output)
      {:ok, {output, status}} -> {:error, {:exit_status, status, output}}
      {:exit, reason} -> {:error, {:crashed, reason}}
      nil -> {:error, :timeout}
    end
  end

  @doc false
  def build_prompt(%Item{room: room} = item) do
    space = room.space

    """
    Du arbetar i rummet "#{room.name}" i utrymmet "#{space.name}" i M4W.

    Utrymmets mål: #{blank_or(space.goal, "(inget angivet)")}
    Rummets delmål: #{blank_or(room.subgoal, "(inget angivet)")}
    Rummet öppnar när: #{blank_or(room.key, "(inget villkor angivet)")}

    Ditt ärende: #{item.title}
    #{meta_line(item.meta)}
    Utför arbetet genom att skapa/redigera filer i din nuvarande arbetskatalog. \
    Svara kort med en sammanfattning av vad du gjorde.
    """
  end

  defp meta_line(meta) when meta in [nil, ""], do: ""
  defp meta_line(meta), do: "Detaljer: #{meta}\n"

  defp blank_or(value, _fallback) when value not in [nil, ""], do: value
  defp blank_or(_value, fallback), do: fallback

  defp workspace_dir(%Item{room: room, id: id}) do
    Path.join(config()[:workspace_root] || "/workspaces", "space-#{room.space_id}-item-#{id}")
  end

  defp timeout_ms, do: config()[:claude_timeout_ms] || 600_000

  defp config, do: Application.get_env(:m4w, :agent_runner, [])

  # `stderr_to_stdout: true` means `output` can be prefixed with warning
  # lines (e.g. "Warning: no stdin data received...") before the actual
  # `--output-format json` payload, which is always the last line.
  defp parse_result(output) do
    json_line = output |> String.split("\n", trim: true) |> List.last() || ""

    case Jason.decode(json_line) do
      {:ok, %{"is_error" => true} = decoded} -> {:error, {:agent_error, decoded}}
      {:ok, %{"result" => result}} -> {:ok, %{summary: result}}
      {:ok, decoded} -> {:error, {:unexpected_output, decoded}}
      {:error, _reason} -> {:error, {:invalid_json, output}}
    end
  end
end
