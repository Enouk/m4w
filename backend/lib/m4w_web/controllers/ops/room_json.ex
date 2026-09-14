defmodule M4wWeb.Ops.RoomJSON do
  alias M4w.Ops
  alias M4w.Ops.Room
  alias M4wWeb.Ops.EntityJSON

  def index(%{rooms: rooms}), do: %{data: Enum.map(rooms, &data/1)}
  def show(%{room: room}), do: %{data: data(room)}

  def data(%Room{} = room) do
    entities = Ops.list_room_entities(room)

    %{
      id: to_string(room.id),
      spaceId: to_string(room.space_id),
      name: room.name,
      order: room.position,
      # transitional — remove once frontend/mail reads `entities` instead of `entity`
      entity: derived_entity(entities),
      entities: Enum.map(entities, &EntityJSON.data/1),
      subgoal: room.subgoal,
      key: room.key,
      itemCount: Ops.room_item_count(room)
    }
  end

  defp derived_entity([]), do: %{kind: "ai", label: nil}

  defp derived_entity(entities) do
    primary = Enum.find(entities, &(&1.kind == "ai")) || List.first(entities)
    %{kind: primary.kind, label: primary.name}
  end
end
