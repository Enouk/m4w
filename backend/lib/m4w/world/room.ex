defmodule M4w.World.Room do
  @moduledoc """
  A location inside a space.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.World.{Artifact, Door, Entity, Passage, Space}

  schema "rooms" do
    field :key, :string
    field :name, :string
    field :description, :string
    field :kind, :string, default: "place"
    field :x, :integer
    field :y, :integer
    field :z, :integer
    field :metadata, :map, default: %{}

    belongs_to :space, Space
    has_many :entities, Entity
    has_many :artifacts, Artifact
    has_many :outbound_passages, Passage, foreign_key: :from_room_id
    has_many :inbound_passages, Passage, foreign_key: :to_room_id
    has_many :doors_as_room_a, Door, foreign_key: :room_a_id
    has_many :doors_as_room_b, Door, foreign_key: :room_b_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:space_id, :key, :name, :description, :kind, :x, :y, :z, :metadata])
    |> validate_required([:space_id, :key, :name, :kind])
    |> validate_length(:key, max: 255)
    |> validate_length(:name, max: 255)
    |> validate_length(:kind, max: 255)
    |> foreign_key_constraint(:space_id)
    |> unique_constraint([:space_id, :key])
  end
end
