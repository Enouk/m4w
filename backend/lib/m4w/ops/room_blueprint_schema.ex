defmodule M4w.Ops.RoomBlueprintSchema do
  @moduledoc """
  JSON Schema for generating an Ops Space's Room pipeline via an LLM
  provider (see `M4w.Design`).

  `M4w.Ops.Room` is deliberately flatter than `M4w.World.Room` — no
  separate door/key graph, just an ordered list of rooms where each room's
  `key` is a short human-readable condition that gates moving into it.
  """

  def schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => ["rooms"],
      "properties" => %{
        "rooms" => %{
          "type" => "array",
          "description" => "The ordered pipeline of Rooms work moves through, first to last.",
          "minItems" => 1,
          "maxItems" => 8,
          "items" => %{
            "type" => "object",
            "additionalProperties" => false,
            "required" => ["name", "subgoal", "entity_kind", "entity_label", "key"],
            "properties" => %{
              "name" => %{
                "type" => "string",
                "description" => "Room name.",
                "maxLength" => 255
              },
              "subgoal" => %{
                "type" => "string",
                "description" => "What must be true for this Room's work to be considered done."
              },
              "entity_kind" => %{
                "type" => "string",
                "enum" => ["ai", "human", "mixed"],
                "description" => "Who works in this Room."
              },
              "entity_label" => %{
                "type" => "string",
                "description" =>
                  "Short label for who/what works here, e.g. \"AI\" or \"Ansvarig\".",
                "maxLength" => 255
              },
              "key" => %{
                "type" => "string",
                "description" =>
                  "Short, human-readable condition that opens this Room, e.g. \"öppnar när underlag är komplett\"."
              }
            }
          }
        }
      }
    }
  end
end
