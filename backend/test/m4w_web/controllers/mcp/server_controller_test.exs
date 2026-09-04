defmodule M4wWeb.MCP.ServerControllerTest do
  use M4wWeb.ConnCase, async: true

  alias M4w.Repo
  alias M4w.World.{Goal, Space}

  describe "POST /mcp" do
    test "initializes the MCP server", %{conn: conn} do
      conn =
        post_mcp(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "initialize",
          "params" => %{
            "protocolVersion" => "2025-11-25",
            "capabilities" => %{},
            "clientInfo" => %{"name" => "test-client", "version" => "1.0.0"}
          }
        })

      assert %{
               "jsonrpc" => "2.0",
               "id" => 1,
               "result" => %{
                 "protocolVersion" => "2025-11-25",
                 "capabilities" => %{"tools" => %{"listChanged" => false}},
                 "serverInfo" => %{"name" => "m4w", "version" => "0.1.0"}
               }
             } = json_response(conn, 200)
    end

    test "lists tools", %{conn: conn} do
      conn =
        post_mcp(conn, %{
          "jsonrpc" => "2.0",
          "id" => "tools",
          "method" => "tools/list"
        })

      assert %{"result" => %{"tools" => tools}} = json_response(conn, 200)

      assert %{
               "name" => "create_space",
               "inputSchema" => %{"type" => "object"},
               "outputSchema" => %{"type" => "object"}
             } = Enum.find(tools, &(&1["name"] == "create_space"))
    end

    test "creates a goal and space through the create_space tool", %{conn: conn} do
      conn =
        post_mcp(conn, %{
          "jsonrpc" => "2.0",
          "id" => "call-1",
          "method" => "tools/call",
          "params" => %{
            "name" => "create_space",
            "arguments" => %{
              "goal" => %{
                "title" => "Ship the MCP server",
                "description" => "Expose the smallest useful tool flow.",
                "metadata" => %{"source" => "mcp-test"}
              }
            }
          }
        })

      assert %{
               "result" => %{
                 "isError" => false,
                 "content" => [%{"type" => "text", "text" => text}],
                 "structuredContent" => %{
                   "data" => %{
                     "id" => space_id,
                     "name" => "Ship the MCP server",
                     "goal" => %{
                       "id" => goal_id,
                       "title" => "Ship the MCP server",
                       "metadata" => %{"source" => "mcp-test"}
                     }
                   }
                 }
               }
             } = response = json_response(conn, 200)

      assert Jason.decode!(text) == response["result"]["structuredContent"]
      assert Repo.get!(Goal, goal_id).title == "Ship the MCP server"
      assert %Space{goal_id: ^goal_id, name: "Ship the MCP server"} = Repo.get!(Space, space_id)
    end

    test "returns tool execution errors for validation failures", %{conn: conn} do
      conn =
        post_mcp(conn, %{
          "jsonrpc" => "2.0",
          "id" => "call-error",
          "method" => "tools/call",
          "params" => %{
            "name" => "create_space",
            "arguments" => %{"goal" => %{"description" => "No title yet"}}
          }
        })

      assert %{
               "result" => %{
                 "isError" => true,
                 "structuredContent" => %{"errors" => %{"title" => ["can't be blank"]}}
               }
             } = json_response(conn, 200)
    end

    test "returns JSON-RPC errors for unknown methods", %{conn: conn} do
      conn =
        post_mcp(conn, %{
          "jsonrpc" => "2.0",
          "id" => "missing",
          "method" => "resources/list"
        })

      assert %{
               "error" => %{
                 "code" => -32601,
                 "message" => "Method not found: resources/list"
               }
             } = json_response(conn, 200)
    end

    test "accepts notification-only requests without a JSON-RPC response", %{conn: conn} do
      conn =
        post_mcp(conn, %{
          "jsonrpc" => "2.0",
          "method" => "notifications/initialized"
        })

      assert response(conn, 202) == ""
    end

    test "supports JSON-RPC batches and omits notification responses", %{conn: conn} do
      conn =
        post_mcp(conn, [
          %{"jsonrpc" => "2.0", "method" => "notifications/initialized"},
          %{"jsonrpc" => "2.0", "id" => "tools", "method" => "tools/list"}
        ])

      assert [%{"id" => "tools", "result" => %{"tools" => tools}}] = json_response(conn, 200)
      assert Enum.any?(tools, &(&1["name"] == "create_space"))
    end

    test "rejects untrusted origins", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "http://evil.example")
        |> post_mcp(%{
          "jsonrpc" => "2.0",
          "id" => "tools",
          "method" => "tools/list"
        })

      assert %{"error" => %{"message" => "Forbidden Origin"}} = json_response(conn, 403)
    end
  end

  describe "GET /mcp" do
    test "returns method not allowed for unsupported HTTP methods", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get(~p"/mcp")

      assert get_resp_header(conn, "allow") == ["POST"]

      assert %{"error" => %{"message" => "MCP endpoint supports POST requests"}} =
               json_response(conn, 405)
    end
  end

  defp post_mcp(conn, message) do
    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/mcp", Jason.encode!(message))
  end
end
