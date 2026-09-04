defmodule M4wWeb.Ops.ComplianceController do
  use M4wWeb, :controller

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, checks: Ops.list_compliance(conn.assigns.space))
  end
end
