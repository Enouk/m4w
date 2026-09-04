defmodule M4wWeb.MCP.ServerController do
  use M4wWeb, :controller

  alias M4wWeb.MCP.Protocol

  def handle(conn, _params) do
    with :ok <- validate_origin(conn) do
      conn.params
      |> Protocol.handle()
      |> send_mcp_response(conn)
    else
      {:error, :forbidden_origin} ->
        conn
        |> put_status(:forbidden)
        |> json(Protocol.error_response(nil, -32000, "Forbidden Origin"))
    end
  end

  def unsupported(conn, _params) do
    conn
    |> put_resp_header("allow", "POST")
    |> put_status(:method_not_allowed)
    |> json(Protocol.error_response(nil, -32000, "MCP endpoint supports POST requests"))
  end

  defp send_mcp_response({:ok, response}, conn) do
    json(conn, response)
  end

  defp send_mcp_response(:no_response, conn) do
    send_resp(conn, :accepted, "")
  end

  defp validate_origin(conn) do
    case get_req_header(conn, "origin") do
      [] ->
        :ok

      [origin | _] ->
        if trusted_origin?(conn, URI.parse(origin)) do
          :ok
        else
          {:error, :forbidden_origin}
        end
    end
  end

  defp trusted_origin?(conn, %URI{host: host, port: port, scheme: scheme}) when is_binary(host) do
    host == conn.host and (port || default_port(scheme)) == conn.port
  end

  defp trusted_origin?(_conn, _uri), do: false

  defp default_port("https"), do: 443
  defp default_port(_scheme), do: 80
end
