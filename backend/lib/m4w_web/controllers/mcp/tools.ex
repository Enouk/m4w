defmodule M4wWeb.MCP.Tools do
  @moduledoc false

  alias M4w.World
  alias M4wWeb.RestAPI.SpaceJSON

  def list_tools do
    [create_space_tool()]
  end

  def call_tool("create_space", arguments) when is_map(arguments) do
    arguments
    |> normalize_create_space_arguments()
    |> case do
      {:ok, goal_params} ->
        create_space(goal_params)

      {:error, errors} ->
        {:ok, tool_error(%{"errors" => errors})}
    end
  end

  def call_tool("create_space", _arguments) do
    {:error, "Tool arguments must be an object"}
  end

  def call_tool(name, _arguments) do
    {:error, "Unknown tool: #{name}"}
  end

  defp normalize_create_space_arguments(%{"goal" => goal}) when is_binary(goal) do
    {:ok, %{"title" => goal}}
  end

  defp normalize_create_space_arguments(%{"goal" => goal}) when is_map(goal) do
    {:ok, goal}
  end

  defp normalize_create_space_arguments(%{"title" => _title} = goal) do
    {:ok, goal}
  end

  defp normalize_create_space_arguments(_arguments) do
    {:error, %{"goal" => ["must be a string or an object with a title"]}}
  end

  defp create_space(goal_params) do
    case World.create_space_from_goal(goal_params) do
      {:ok, space} ->
        {:ok, tool_success(SpaceJSON.show(%{space: space}))}

      {:error, _operation, changeset} ->
        {:ok, tool_error(%{"errors" => translate_errors(changeset)})}
    end
  end

  defp tool_success(structured_content) do
    %{
      "content" => [%{"type" => "text", "text" => Jason.encode!(structured_content)}],
      "structuredContent" => structured_content,
      "isError" => false
    }
  end

  defp tool_error(structured_content) do
    %{
      "content" => [%{"type" => "text", "text" => Jason.encode!(structured_content)}],
      "structuredContent" => structured_content,
      "isError" => true
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts
        |> Keyword.get(String.to_existing_atom(key), key)
        |> to_string()
      end)
    end)
  end

  defp create_space_tool do
    %{
      "name" => "create_space",
      "title" => "Create space",
      "description" =>
        "Creates a goal and the first space for that goal. Accepts the same payload shape as POST /api/spaces.",
      "inputSchema" => %{
        "type" => "object",
        "properties" => %{
          "goal" => %{
            "description" =>
              "A goal title string, or a goal object with title, description, status, and metadata.",
            "oneOf" => [
              %{"type" => "string"},
              goal_input_schema()
            ]
          },
          "title" => %{"type" => "string", "description" => "Goal title."},
          "description" => %{"type" => "string", "description" => "Goal description."},
          "status" => %{"type" => "string", "description" => "Goal status."},
          "metadata" => %{"type" => "object", "description" => "Free-form goal metadata."}
        },
        "additionalProperties" => false
      },
      "outputSchema" => %{
        "type" => "object",
        "properties" => %{
          "data" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "integer"},
              "name" => %{"type" => "string"},
              "description" => %{"type" => ["string", "null"]},
              "metadata" => %{"type" => "object"},
              "goal" => goal_output_schema(),
              "inserted_at" => %{"type" => ["string", "null"], "format" => "date-time"},
              "updated_at" => %{"type" => ["string", "null"], "format" => "date-time"}
            },
            "required" => ["id", "name", "metadata", "goal"]
          }
        },
        "required" => ["data"]
      },
      "annotations" => %{
        "destructiveHint" => false,
        "idempotentHint" => false,
        "openWorldHint" => false
      }
    }
  end

  defp goal_input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "title" => %{"type" => "string"},
        "description" => %{"type" => "string"},
        "status" => %{"type" => "string"},
        "metadata" => %{"type" => "object"}
      },
      "required" => ["title"],
      "additionalProperties" => false
    }
  end

  defp goal_output_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "integer"},
        "title" => %{"type" => "string"},
        "description" => %{"type" => ["string", "null"]},
        "status" => %{"type" => "string"},
        "metadata" => %{"type" => "object"},
        "inserted_at" => %{"type" => ["string", "null"], "format" => "date-time"},
        "updated_at" => %{"type" => ["string", "null"], "format" => "date-time"}
      },
      "required" => ["id", "title", "status", "metadata"]
    }
  end
end
