defmodule M4wWeb.Ops.DecisionController do
  use M4wWeb, :controller

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, decisions: Ops.list_decisions(conn.assigns.space))
  end
end
