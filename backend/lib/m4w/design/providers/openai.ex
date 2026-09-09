defmodule M4w.Design.Providers.OpenAI do
  @moduledoc """
  Designs a blueprint by calling OpenAI's Chat Completions API.

  Forces a single function call whose parameters schema is `request.schema`
  (OpenAI's equivalent of `M4w.Design.Providers.Anthropic`'s forced tool
  use), so every successful response is a schema-valid blueprint.
  """

  @behaviour M4w.Design.Provider

  @api_url "https://api.openai.com/v1/chat/completions"

  @impl true
  def name, do: "openai"

  @impl true
  def design(request, opts) do
    model = Keyword.fetch!(opts, :model)

    body = %{
      model: model,
      messages: [
        %{role: "system", content: request.system_prompt},
        %{role: "user", content: request.user_prompt}
      ],
      tools: [
        %{
          type: "function",
          function: %{
            name: request.tool_name,
            description: request.tool_description,
            parameters: request.schema,
            strict: true
          }
        }
      ],
      tool_choice: %{type: "function", function: %{name: request.tool_name}}
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

  defp headers, do: [{"authorization", "Bearer " <> api_key()}]

  defp api_key do
    Application.get_env(:m4w, :design, [])[:openai_api_key] ||
      raise "OPENAI_API_KEY is not configured (set it in backend/.env)"
  end

  defp parse_response(%{"choices" => [%{"message" => message} | _], "usage" => usage}, tool_name) do
    tool_calls = message["tool_calls"] || []

    case Enum.find(tool_calls, &(&1["function"]["name"] == tool_name)) do
      %{"function" => %{"arguments" => arguments}} ->
        case Jason.decode(arguments) do
          {:ok, blueprint} when is_map(blueprint) ->
            {:ok,
             %{
               blueprint: blueprint,
               usage: %{
                 input_tokens: usage["prompt_tokens"] || 0,
                 output_tokens: usage["completion_tokens"] || 0
               }
             }}

          _ ->
            {:error, {:invalid_tool_arguments, arguments}}
        end

      _ ->
        {:error, {:no_tool_call, tool_calls}}
    end
  end

  defp parse_response(other, _tool_name), do: {:error, {:unexpected_response, other}}
end
