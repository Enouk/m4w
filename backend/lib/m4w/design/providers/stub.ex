defmodule M4w.Design.Providers.Stub do
  @moduledoc """
  Deterministic provider that returns a small valid blueprint without making
  a network call. Used in tests, and as the safe default in dev/test when no
  `ANTHROPIC_API_KEY` is configured — so the feature never silently spends
  money on an unconfigured install.

  Dispatches on `request.tool_name` since it has to return a shape that
  matches whichever domain (`M4w.World` or `M4w.Ops`) asked.
  """

  @behaviour M4w.Design.Provider

  @impl true
  def name, do: "stub"

  @impl true
  def design(%{tool_name: "emit_space_blueprint"}, _opts) do
    {:ok, %{blueprint: world_blueprint(), usage: %{input_tokens: 120, output_tokens: 340}}}
  end

  def design(%{tool_name: "emit_room_blueprint"}, _opts) do
    {:ok, %{blueprint: ops_blueprint(), usage: %{input_tokens: 90, output_tokens: 260}}}
  end

  # `space.name` isn't part of the request — M4w.World falls back to the
  # goal's title when the blueprint doesn't set one, so it's left out here.
  defp world_blueprint do
    %{
      "space" => %{"description" => "Genererad av stub-providern."},
      "rooms" => [
        %{"key" => "analysis", "name" => "Analys", "kind" => "analysis"},
        %{"key" => "implementation", "name" => "Implementation", "kind" => "implementation"}
      ],
      "doors" => [
        %{
          "name" => "Grind till implementation",
          "room_a_key" => "analysis",
          "room_b_key" => "implementation",
          "locked" => false
        }
      ],
      "keys" => [],
      "entities" => [],
      "artifacts" => [
        %{"key" => "analysis_notes", "name" => "Analysanteckningar", "room_key" => "analysis"}
      ],
      "passages" => []
    }
  end

  defp ops_blueprint do
    %{
      "rooms" => [
        %{
          "name" => "Inkorg",
          "subgoal" => "Nya mail klassificerade",
          "entity_kind" => "ai",
          "entity_label" => "AI",
          "key" => "öppnar när typ ≠ okänd"
        },
        %{
          "name" => "Behandling",
          "subgoal" => "Ärendet berett och redo för beslut",
          "entity_kind" => "mixed",
          "entity_label" => "AI + Människa",
          "key" => "öppnar när underlag är komplett"
        }
      ]
    }
  end
end
