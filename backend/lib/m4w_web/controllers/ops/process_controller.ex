defmodule M4wWeb.Ops.ProcessController do
  use M4wWeb, :controller

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, processes: Ops.list_processes(conn.assigns.current_user))
  end
end
