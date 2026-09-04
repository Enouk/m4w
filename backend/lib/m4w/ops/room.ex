defmodule M4w.Ops.Room do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Item, Space}

  schema "ops_rooms" do
    field :name, :string
    field :position, :integer, default: 0
    field :entity_kind, :string, default: "ai"
    field :entity_label, :string
    field :subgoal, :string
    field :key, :string

    belongs_to :space, Space
    has_many :items, Item

    timestamps(type: :utc_datetime)
  end

  @entity_kinds ~w(ai human mixed)

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:space_id, :name, :position, :entity_kind, :entity_label, :subgoal, :key])
    |> validate_required([:space_id, :name])
    |> validate_inclusion(:entity_kind, @entity_kinds)
    |> foreign_key_constraint(:space_id)
  end
end
