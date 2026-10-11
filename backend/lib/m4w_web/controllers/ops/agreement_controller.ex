defmodule M4wWeb.Ops.AgreementController do
  use M4wWeb, :controller

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, revisions: Ops.list_agreement_revisions(conn.assigns.space))
  end
end
