defmodule M4wWeb.Ops.VerificationController do
  use M4wWeb, :controller

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, verifications: Ops.list_verifications(conn.assigns.space))
  end
end
