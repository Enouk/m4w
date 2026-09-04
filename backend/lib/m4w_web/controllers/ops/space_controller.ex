defmodule M4wWeb.Ops.SpaceController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops
  alias M4wWeb.Ops.GenerateJSON

  def index(conn, _params) do
    render(conn, :index, spaces: Ops.list_spaces_for_user(conn.assigns.current_user))
  end

  def create(conn, params) do
    with {:ok, space} <- Ops.create_space_for_user(conn.assigns.current_user, params) do
      conn |> put_status(:created) |> render(:show, space: space)
    end
  end

  def show(conn, _params), do: render(conn, :show, space: conn.assigns.space)

  def update(conn, params) do
    with {:ok, space} <- Ops.update_space(conn.assigns.space, params) do
      render(conn, :show, space: space)
    end
  end

  def delete(conn, _params) do
    with {:ok, _} <- Ops.delete_space(conn.assigns.space) do
      send_resp(conn, :no_content, "")
    end
  end

  def generate(conn, _params) do
    rooms = Ops.generate_rooms(conn.assigns.space)
    conn |> put_view(json: GenerateJSON) |> render(:show, rooms: rooms)
  end
end
