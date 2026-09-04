defmodule M4wWeb.MCP.Protocol do
  @moduledoc false

  alias M4wWeb.MCP.Tools

  @supported_protocol_versions ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]
  @latest_protocol_version hd(@supported_protocol_versions)

  def handle(%{"_json" => messages}) when is_list(messages), do: handle(messages)

  def handle(messages) when is_list(messages) do
    responses =
      messages
      |> Enum.flat_map(fn
        message ->
          case handle_message(message) do
            {:ok, response} -> [response]
            :no_response -> []
          end
      end)

    case responses do
      [] -> :no_response
      responses -> {:ok, responses}
    end
  end

  def handle(message), do: handle_message(message)

  defp handle_message(%{"jsonrpc" => "2.0", "id" => id, "method" => "initialize"} = message)
       when not is_nil(id) do
    params = Map.get(message, "params", %{})
    client_protocol_version = Map.get(params, "protocolVersion")

    result = %{
      "protocolVersion" => negotiate_protocol_version(client_protocol_version),
      "capabilities" => %{
        "tools" => %{
          "listChanged" => false
        }
      },
      "serverInfo" => %{
        "name" => "m4w",
        "version" => "0.1.0"
      }
    }

    {:ok, response(id, result)}
  end

  defp handle_message(%{"jsonrpc" => "2.0", "method" => "notifications/initialized"}) do
    :no_response
  end

  defp handle_message(%{"jsonrpc" => "2.0", "id" => id, "method" => "ping"})
       when not is_nil(id) do
    {:ok, response(id, %{})}
  end

  defp handle_message(%{"jsonrpc" => "2.0", "id" => id, "method" => "tools/list"})
       when not is_nil(id) do
    {:ok, response(id, %{"tools" => Tools.list_tools()})}
  end

  defp handle_message(
         %{
           "jsonrpc" => "2.0",
           "id" => id,
           "method" => "tools/call",
           "params" => %{"name" => name}
         } = message
       )
       when not is_nil(id) do
    arguments =
      message
      |> get_in(["params", "arguments"])
      |> case do
        nil -> %{}
        arguments -> arguments
      end

    case Tools.call_tool(name, arguments) do
      {:ok, result} ->
        {:ok, response(id, result)}

      {:error, message} ->
        {:ok, error_response(id, -32602, message)}
    end
  end

  defp handle_message(%{"jsonrpc" => "2.0", "id" => id, "method" => method})
       when not is_nil(id) and is_binary(method) do
    {:ok, error_response(id, -32601, "Method not found: #{method}")}
  end

  defp handle_message(%{"jsonrpc" => "2.0"}) do
    :no_response
  end

  defp handle_message(%{"id" => id}) do
    {:ok, error_response(id, -32600, "Invalid JSON-RPC request")}
  end

  defp handle_message(_message) do
    {:ok, error_response(nil, -32600, "Invalid JSON-RPC request")}
  end

  def error_response(id, code, message, data \\ nil) do
    error = %{"code" => code, "message" => message}

    error =
      if is_nil(data) do
        error
      else
        Map.put(error, "data", data)
      end

    %{"jsonrpc" => "2.0", "id" => id, "error" => error}
  end

  defp response(id, result) do
    %{"jsonrpc" => "2.0", "id" => id, "result" => result}
  end

  defp negotiate_protocol_version(version) when version in @supported_protocol_versions,
    do: version

  defp negotiate_protocol_version(_version), do: @latest_protocol_version
end
