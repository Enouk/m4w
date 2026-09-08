defmodule M4w.Design.Providers.Anthropic do
  @moduledoc """
  Designs a blueprint by calling Claude (the Anthropic Messages API).

  Forces a single tool call whose input schema is `request.schema`, so every
  successful response is a schema-valid blueprint — no separate
  JSON-parsing/validation step needed. Fully generic: the caller
  (`M4w.World` or `M4w.Ops`) supplies the prompts, tool name, and schema.
  """

  @behaviour M4w.Design.Provider

  @api_url "https://api.anthropic.com/v1/messages"
  @anthropic_version "2023-06-01"

  @impl true
  def name, do: "anthropic"

  @impl true
  def design(request, opts) do
    model = Keyword.fetch!(opts, :model)

    body = %{
      model: model,
      max_tokens: 16_000,
      system: request.system_prompt,
      messages: [%{role: "user", content: request.user_prompt}],
      tools: [
        %{
          name: request.tool_name,
          description: request.tool_description,
          input_schema: request.schema,
          strict: true
        }
      ],
      tool_choice: %{type: "tool", name: request.tool_name}
    }

    @api_url
    |> Req.post(json: body, headers: headers(), receive_timeout: 120_000)
    |> handle_response(request.tool_name)
  end

  defp handle_response({:ok, %{status: 200, body: response_body}}, tool_name),
    do: parse_response(response_body, tool_name)

  defp handle_response({:ok, %{status: status, body: response_body}}, _tool_name),
    do: {:error, {:unexpected_status, status, response_body}}

  defp handle_response({:error, reason}, _tool_name), do: {:error, reason}

  defp headers do
    [{"x-api-key", api_key()}, {"anthropic-version", @anthropic_version}]
  end

  defp api_key do
    Application.get_env(:m4w, :design, [])[:anthropic_api_key] ||
      raise "ANTHROPIC_API_KEY is not configured (set it in backend/.env)"
  end

  defp parse_response(%{"content" => content, "usage" => usage}, tool_name) do
    case Enum.find(content, &(&1["type"] == "tool_use" && &1["name"] == tool_name)) do
      %{"input" => blueprint} when is_map(blueprint) ->
        {:ok,
         %{
           blueprint: blueprint,
           usage: %{
             input_tokens: usage["input_tokens"] || 0,
             output_tokens: usage["output_tokens"] || 0
           }
         }}

      _ ->
        {:error, {:no_tool_use_block, content}}
    end
  end

  defp parse_response(other, _tool_name), do: {:error, {:unexpected_response, other}}
end
