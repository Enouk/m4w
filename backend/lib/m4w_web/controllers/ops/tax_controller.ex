defmodule M4wWeb.Ops.TaxController do
  use M4wWeb, :controller

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, checks: Ops.list_tax_checks(conn.assigns.space))
  end
end
