defmodule M4wWeb.Ops.EntityController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops

  def index(conn, %{"roomId" => room_id}) do
    room = Ops.get_room!(conn.assigns.space, room_id)
    render(conn, :index, entities: Ops.list_room_entities(room))
  end

  def create(conn, %{"roomId" => room_id} = params) do
    room = Ops.get_room!(conn.assigns.space, room_id)

    with {:ok, entity} <- Ops.create_entity(room, params) do
      conn |> put_status(:created) |> render(:show, entity: entity)
    end
  end

  def update(conn, %{"entityId" => entity_id} = params) do
    entity = Ops.get_entity!(entity_id)

    with :ok <- authorize(conn, entity),
         {:ok, entity} <- Ops.update_entity(entity, params) do
      render(conn, :show, entity: entity)
    end
  end

  def delete(conn, %{"entityId" => entity_id}) do
    entity = Ops.get_entity!(entity_id)

    with :ok <- authorize(conn, entity),
         {:ok, _} <- Ops.delete_entity(entity) do
      send_resp(conn, :no_content, "")
    end
  end

  defp authorize(conn, entity) do
    if Ops.user_has_space_access?(conn.assigns.current_user, entity.room.space_id) do
      :ok
    else
      {:error, :forbidden}
    end
  end
end
