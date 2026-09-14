defmodule M4wWeb.PageController do
  use M4wWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def frontend(conn, params) do
    app = Map.get(params, "app", "mail")

    if String.ends_with?(conn.request_path, "/") do
      path = Path.join([:code.priv_dir(:m4w), "static", "frontend", app, "index.html"])

      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, File.read!(path))
    else
      redirect(conn, to: conn.request_path <> "/")
    end
  end

  def frontend_code(conn, params), do: frontend(conn, Map.put(params, "app", "code"))
end
