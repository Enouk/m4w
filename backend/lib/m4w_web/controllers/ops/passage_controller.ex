defmodule M4wWeb.Ops.PassageController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, passages: Ops.list_passages(conn.assigns.space))
  end

  def create(conn, params) do
    with {:ok, passage} <- Ops.create_passage(conn.assigns.space, params) do
      conn |> put_status(:created) |> render(:show, passage: passage)
    end
  end
end
