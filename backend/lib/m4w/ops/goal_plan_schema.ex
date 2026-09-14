defmodule M4w.Ops.GoalPlanSchema do
  @moduledoc """
  JSON Schema for drafting the set of sibling `M4w.Ops.Space`s needed to
  reach a `M4w.Ops.Goal`, via an LLM provider (see `M4w.Design`).

  This is the "plan mode" step: each drafted space becomes its own Space
  with its own Room/Item pipeline once confirmed — this schema only
  captures the top-level breakdown (name + subgoal), not each space's
  internal pipeline.
  """

  def schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => ["spaces"],
      "properties" => %{
        "spaces" => %{
          "type" => "array",
          "description" =>
            "The ordered set of Spaces needed to reach the goal, first to last.",
          "minItems" => 1,
          "maxItems" => 8,
          "items" => %{
            "type" => "object",
            "additionalProperties" => false,
            "required" => ["name", "subgoal"],
            "properties" => %{
              "name" => %{
                "type" => "string",
                "description" => "Space name.",
                "maxLength" => 255
              },
              "subgoal" => %{
                "type" => "string",
                "description" => "What this Space must accomplish to help reach the overall goal."
              }
            }
          }
        }
      }
    }
  end
end
