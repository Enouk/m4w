defmodule M4w.Ops.Passage do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Item, Room, Space}

  schema "ops_passages" do
    field :text, :string
    field :occurred_at, :utc_datetime

    belongs_to :space, Space
    belongs_to :item, Item
    belongs_to :from_room, Room
    belongs_to :to_room, Room

    timestamps(type: :utc_datetime)
  end

  def changeset(passage, attrs) do
    passage
    |> cast(attrs, [:space_id, :item_id, :from_room_id, :to_room_id, :text, :occurred_at])
    |> validate_required([:space_id, :text, :occurred_at])
    |> foreign_key_constraint(:space_id)
  end
end
