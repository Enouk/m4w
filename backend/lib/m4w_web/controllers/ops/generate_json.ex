defmodule M4wWeb.Ops.GenerateJSON do
  alias M4w.Ops.Room
  alias M4wWeb.Ops.RoomJSON

  def show(%{rooms: rooms}), do: %{rooms: Enum.map(rooms, &room_data/1)}

  defp room_data(%Room{} = room), do: RoomJSON.data(room)

  defp room_data(%{} = draft) do
    %{
      id: draft.temp_id,
      spaceId: nil,
      name: draft.name,
      order: draft.position,
      entity: %{kind: draft.entity_kind, label: draft.entity_label},
      subgoal: draft.subgoal,
      key: draft.key,
      itemCount: 0
    }
  end
end
