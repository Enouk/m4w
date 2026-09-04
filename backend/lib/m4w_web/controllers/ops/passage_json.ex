defmodule M4wWeb.Ops.PassageJSON do
  alias M4w.Ops.Passage

  def index(%{passages: passages}), do: %{data: Enum.map(passages, &data/1)}
  def show(%{passage: passage}), do: %{data: data(passage)}

  def data(%Passage{} = passage) do
    %{
      id: to_string(passage.id),
      spaceId: to_string(passage.space_id),
      itemId: passage.item_id && to_string(passage.item_id),
      text: passage.text,
      timestamp: DateTime.to_iso8601(passage.occurred_at),
      fromRoomId: passage.from_room_id && to_string(passage.from_room_id),
      toRoomId: passage.to_room_id && to_string(passage.to_room_id)
    }
  end
end
