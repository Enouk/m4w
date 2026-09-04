defmodule M4wWeb.Ops.RoomJSON do
  alias M4w.Ops
  alias M4w.Ops.Room

  def index(%{rooms: rooms}), do: %{data: Enum.map(rooms, &data/1)}
  def show(%{room: room}), do: %{data: data(room)}

  def data(%Room{} = room) do
    %{
      id: to_string(room.id),
      spaceId: to_string(room.space_id),
      name: room.name,
      order: room.position,
      entity: %{kind: room.entity_kind, label: room.entity_label},
      subgoal: room.subgoal,
      key: room.key,
      itemCount: Ops.room_item_count(room)
    }
  end
end
