defmodule M4wWeb.Ops.ItemController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops

  def index(conn, %{"roomId" => room_id}) do
    room = Ops.get_room!(conn.assigns.space, room_id)
    render(conn, :index, items: Ops.list_room_items(room))
  end

  def show(conn, %{"itemId" => item_id}) do
    item = Ops.get_item!(item_id)

    with :ok <- authorize(conn, item) do
      render(conn, :detail, item: item)
    end
  end

  def update(conn, %{"itemId" => item_id} = params) do
    item = Ops.get_item!(item_id)

    with :ok <- authorize(conn, item),
         {:ok, item} <- Ops.update_item(item, params) do
      render(conn, :show, item: item)
    end
  end

  defp authorize(conn, item) do
    if Ops.user_has_space_access?(conn.assigns.current_user, item.room.space_id) do
      :ok
    else
      {:error, :forbidden}
    end
  end
end
