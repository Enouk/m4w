defmodule M4w.Ops.Room do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Entity, Item, Space}

  schema "ops_rooms" do
    field :name, :string
    field :position, :integer, default: 0
    field :subgoal, :string
    field :key, :string

    belongs_to :space, Space
    has_many :items, Item
    many_to_many :entities, Entity, join_through: "ops_room_entities"

    timestamps(type: :utc_datetime)
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:space_id, :name, :position, :subgoal, :key])
    |> validate_required([:space_id, :name])
    |> foreign_key_constraint(:space_id)
  end
end
