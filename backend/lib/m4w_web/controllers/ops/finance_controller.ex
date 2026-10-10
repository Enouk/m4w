defmodule M4wWeb.Ops.FinanceController do
  use M4wWeb, :controller

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, entries: Ops.list_finance_entries(conn.assigns.space))
  end
end
