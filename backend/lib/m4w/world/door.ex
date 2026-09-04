defmodule M4w.World.Door do
  @moduledoc """
  A physical or logical barrier that connects two rooms.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.World.{DoorKey, Key, Passage, Room, Space}

  schema "doors" do
    field :name, :string
    field :description, :string
    field :state, :string, default: "open"
    field :locked, :boolean, default: false
    field :metadata, :map, default: %{}

    belongs_to :space, Space
    belongs_to :room_a, Room
    belongs_to :room_b, Room
    has_many :door_keys, DoorKey
    has_many :passages, Passage

    many_to_many :keys, Key,
      join_through: DoorKey,
      join_keys: [door_id: :id, key_id: :id]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(door, attrs) do
    door
    |> cast(attrs, [
      :space_id,
      :room_a_id,
      :room_b_id,
      :name,
      :description,
      :state,
      :locked,
      :metadata
    ])
    |> validate_required([:space_id, :room_a_id, :room_b_id, :name, :state, :locked])
    |> validate_length(:name, max: 255)
    |> validate_length(:state, max: 255)
    |> validate_distinct_rooms()
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:room_a_id)
    |> foreign_key_constraint(:room_b_id)
    |> check_constraint(:room_b_id, name: :doors_room_a_and_room_b_must_differ)
  end

  defp validate_distinct_rooms(changeset) do
    room_a_id = get_field(changeset, :room_a_id)
    room_b_id = get_field(changeset, :room_b_id)

    if room_a_id && room_a_id == room_b_id do
      add_error(changeset, :room_b_id, "must differ from room_a_id")
    else
      changeset
    end
  end
end
