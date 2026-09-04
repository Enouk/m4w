defmodule M4w.World.SpaceJsonSchema do
  @moduledoc """
  JSON Schema for generating a world space blueprint.

  The persisted world model uses database ids for relationships. This schema is
  intended for generation before persistence, so it references rooms by
  `room.key`, keys by `key.code`, and artifacts by `artifact.key`.
  """

  @schema_id "https://m4w.local/schemas/world/space-blueprint.schema.json"

  def id, do: @schema_id

  def json do
    Jason.encode!(schema())
  end

  def schema do
    %{
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "$id" => @schema_id,
      "title" => "M4w World Space Blueprint",
      "description" =>
        "A generated space for a MUD for Work goal, including rooms, entities, doors, keys, artifacts, and passages.",
      "type" => "object",
      "additionalProperties" => false,
      "required" => ["space", "rooms", "doors", "keys", "artifacts", "entities", "passages"],
      "properties" => %{
        "goal" => %{"$ref" => "#/$defs/goal"},
        "space" => %{"$ref" => "#/$defs/space"},
        "rooms" => %{
          "type" => "array",
          "description" => "Rooms where work happens. Room keys must be unique within the space.",
          "minItems" => 1,
          "items" => %{"$ref" => "#/$defs/room"}
        },
        "doors" => %{
          "type" => "array",
          "description" =>
            "Logical or physical barriers between rooms. Room references must match room keys.",
          "items" => %{"$ref" => "#/$defs/door"}
        },
        "keys" => %{
          "type" => "array",
          "description" =>
            "Conditions, permissions, or quality requirements. Key codes must be unique within the space.",
          "items" => %{"$ref" => "#/$defs/key"}
        },
        "entities" => %{
          "type" => "array",
          "description" => "AI agents, human roles, tools, or other things placed in the space.",
          "items" => %{"$ref" => "#/$defs/entity"}
        },
        "artifacts" => %{
          "type" => "array",
          "description" =>
            "Traceable work products such as files, reports, decisions, code, tests, or documentation.",
          "items" => %{"$ref" => "#/$defs/artifact"}
        },
        "passages" => %{
          "type" => "array",
          "description" =>
            "Directed transitions for moving work, context, responsibility, and artifacts between rooms.",
          "items" => %{"$ref" => "#/$defs/passage"}
        }
      },
      "$defs" => defs()
    }
  end

  defp defs do
    %{
      "goal" => %{
        "type" => "object",
        "additionalProperties" => false,
        "required" => ["title"],
        "properties" => %{
          "title" => string("The top-level objective that frames the space.", max_length: 255),
          "description" => nullable_string("More context about the goal."),
          "status" => string("Goal status.", default: "active", max_length: 255),
          "metadata" => metadata()
        }
      },
      "space" => %{
        "type" => "object",
        "additionalProperties" => false,
        "required" => ["name"],
        "properties" => %{
          "name" => string("The generated workspace name.", max_length: 255),
          "description" =>
            nullable_string("A concise explanation of what this space is built to accomplish."),
          "metadata" => metadata()
        }
      },
      "room" => %{
        "type" => "object",
        "additionalProperties" => false,
        "required" => ["key", "name"],
        "properties" => %{
          "key" =>
            slug(
              "Stable identifier used by doors, entities, and passages to reference this room.",
              max_length: 255
            ),
          "name" => string("Human-readable room name.", max_length: 255),
          "description" => nullable_string("What kind of work happens in this room."),
          "kind" =>
            string("Room category, for example analysis, implementation, test, or release.",
              default: "place",
              max_length: 255
            ),
          "x" => nullable_integer("Optional map x coordinate."),
          "y" => nullable_integer("Optional map y coordinate."),
          "z" => nullable_integer("Optional map z coordinate."),
          "metadata" => metadata()
        }
      },
      "door" => %{
        "type" => "object",
        "additionalProperties" => false,
        "required" => ["name", "room_a_key", "room_b_key"],
        "properties" => %{
          "name" => string("Human-readable door or gate name.", max_length: 255),
          "description" => nullable_string("What this door controls."),
          "state" =>
            string("Door state, for example open, closed, blocked, or complete.",
              default: "open",
              max_length: 255
            ),
          "locked" => %{
            "type" => "boolean",
            "description" => "Whether a key requirement must be satisfied before passage.",
            "default" => false
          },
          "room_a_key" => slug("The key of one connected room.", max_length: 255),
          "room_b_key" =>
            slug("The key of the other connected room. Must differ from room_a_key.",
              max_length: 255
            ),
          "key_requirements" => %{
            "type" => "array",
            "description" => "Keys required or recommended for this door.",
            "items" => %{"$ref" => "#/$defs/door_key"}
          },
          "metadata" => metadata()
        }
      },
      "door_key" => %{
        "type" => "object",
        "additionalProperties" => false,
        "required" => ["key_code"],
        "properties" => %{
          "key_code" => slug("The code of a key in the top-level keys array.", max_length: 255),
          "requirement_kind" =>
            string("Requirement type, for example required or recommended.",
              default: "required",
              max_length: 255
            ),
          "metadata" => metadata()
        }
      },
      "key" => %{
        "type" => "object",
        "additionalProperties" => false,
        "required" => ["code", "name"],
        "properties" => %{
          "code" =>
            slug(
              "Stable identifier used by doors and passages to reference this key.",
              max_length: 255
            ),
          "name" => string("Human-readable key name.", max_length: 255),
          "description" => nullable_string("The condition, permission, or quality requirement."),
          "kind" =>
            string("Key category, for example condition, permission, quality, or evidence.",
              default: "condition",
              max_length: 255
            ),
          "status" => string("Current satisfaction status.", default: "pending", max_length: 255),
          "criteria" => object("Machine-readable criteria for satisfying this key."),
          "metadata" => metadata()
        }
      },
      "entity" => %{
        "type" => "object",
        "additionalProperties" => false,
        "required" => ["name"],
        "properties" => %{
          "name" => string("Entity name.", max_length: 255),
          "description" => nullable_string("Role, responsibility, or purpose of the entity."),
          "kind" =>
            string("Entity category, for example agent, human, tool, or item.",
              default: "thing",
              max_length: 255
            ),
          "state" => string("Entity state.", default: "idle", max_length: 255),
          "room_key" => nullable_slug("Optional key of the room where this entity starts."),
          "attributes" => object("Domain attributes for this entity."),
          "metadata" => metadata()
        }
      },
      "artifact" => %{
        "type" => "object",
        "additionalProperties" => false,
        "required" => ["key", "name"],
        "properties" => %{
          "key" =>
            slug(
              "Stable identifier used by passages to reference this artifact.",
              max_length: 255
            ),
          "name" => string("Artifact name.", max_length: 255),
          "description" => nullable_string("What was created, changed, decided, or carried."),
          "kind" =>
            string(
              "Artifact category, for example file, report, decision, code, test, or documentation.",
              default: "work_product",
              max_length: 255
            ),
          "status" => string("Artifact status.", default: "draft", max_length: 255),
          "room_key" =>
            nullable_slug("Optional key of the room where this artifact currently belongs."),
          "content" => object("Machine-readable artifact payload or references."),
          "metadata" => metadata()
        }
      },
      "passage" => %{
        "type" => "object",
        "additionalProperties" => false,
        "required" => [
          "from_room_key",
          "to_room_key",
          "artifact_key",
          "used_key_code",
          "direction"
        ],
        "properties" => %{
          "from_room_key" => slug("The room key where this passage starts.", max_length: 255),
          "to_room_key" =>
            slug("The room key where this passage ends. Must differ from from_room_key.",
              max_length: 255
            ),
          "door_name" => nullable_string("Optional door name this passage passes through."),
          "artifact_key" =>
            slug(
              "The artifact carried by this passage for traceability.",
              max_length: 255
            ),
          "used_key_code" =>
            slug(
              "The key code used to open or justify this passage.",
              max_length: 255
            ),
          "direction" =>
            string("Direction label unique from the same source room.", max_length: 255),
          "name" => nullable_string("Optional passage name.", max_length: 255),
          "description" =>
            nullable_string("What context or responsibility moves through this passage."),
          "conditions" => object("Machine-readable passage conditions."),
          "metadata" => metadata()
        }
      }
    }
  end

  defp metadata do
    object("Free-form metadata for UI hints, generation notes, provenance, or scoring.")
  end

  defp object(description) do
    %{
      "type" => "object",
      "description" => description,
      "default" => %{},
      "additionalProperties" => true
    }
  end

  defp string(description, opts) do
    %{
      "type" => "string",
      "description" => description
    }
    |> put_default(opts)
    |> put_max_length(opts)
  end

  defp nullable_string(description, opts \\ []) do
    %{
      "type" => ["string", "null"],
      "description" => description,
      "default" => nil
    }
    |> put_max_length(opts)
  end

  defp slug(description, opts) do
    description
    |> string(opts)
    |> Map.merge(%{
      "pattern" => "^[a-z][a-z0-9_\\-]*$",
      "examples" => ["analysis", "qa_signoff", "release-gate"]
    })
  end

  defp nullable_slug(description) do
    %{
      "type" => ["string", "null"],
      "description" => description,
      "pattern" => "^[a-z][a-z0-9_\\-]*$",
      "default" => nil,
      "examples" => ["analysis", "qa_signoff", nil]
    }
  end

  defp nullable_integer(description) do
    %{
      "type" => ["integer", "null"],
      "description" => description,
      "default" => nil
    }
  end

  defp put_default(schema, opts) do
    case Keyword.fetch(opts, :default) do
      {:ok, default} -> Map.put(schema, "default", default)
      :error -> schema
    end
  end

  defp put_max_length(schema, opts) do
    case Keyword.fetch(opts, :max_length) do
      {:ok, max_length} -> Map.put(schema, "maxLength", max_length)
      :error -> schema
    end
  end
end
