defmodule M4wWeb.Ops.RoomController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, rooms: Ops.list_rooms(conn.assigns.space))
  end

  def create(conn, params) do
    with {:ok, room} <- Ops.create_room(conn.assigns.space, params) do
      conn |> put_status(:created) |> render(:show, room: room)
    end
  end

  def update(conn, %{"roomId" => room_id} = params) do
    room = Ops.get_room!(conn.assigns.space, room_id)

    with {:ok, room} <- Ops.update_room(room, params) do
      render(conn, :show, room: room)
    end
  end

  def delete(conn, %{"roomId" => room_id}) do
    room = Ops.get_room!(conn.assigns.space, room_id)

    with {:ok, _} <- Ops.delete_room(room) do
      send_resp(conn, :no_content, "")
    end
  end
end
