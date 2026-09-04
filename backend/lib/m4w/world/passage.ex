defmodule M4w.World.Passage do
  @moduledoc """
  A traceable, directed movement of work from one room to another.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.World.{Artifact, Door, Key, Room, Space}

  schema "passages" do
    field :direction, :string
    field :name, :string
    field :description, :string
    field :conditions, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :space, Space
    belongs_to :from_room, Room
    belongs_to :to_room, Room
    belongs_to :door, Door
    belongs_to :artifact, Artifact
    belongs_to :used_key, Key

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(passage, attrs) do
    passage
    |> cast(attrs, [
      :space_id,
      :from_room_id,
      :to_room_id,
      :door_id,
      :artifact_id,
      :used_key_id,
      :direction,
      :name,
      :description,
      :conditions,
      :metadata
    ])
    |> validate_required([
      :space_id,
      :from_room_id,
      :to_room_id,
      :artifact_id,
      :used_key_id,
      :direction
    ])
    |> validate_length(:direction, max: 255)
    |> validate_length(:name, max: 255)
    |> validate_distinct_rooms()
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:from_room_id)
    |> foreign_key_constraint(:to_room_id)
    |> foreign_key_constraint(:door_id)
    |> foreign_key_constraint(:artifact_id)
    |> foreign_key_constraint(:used_key_id)
    |> unique_constraint([:space_id, :from_room_id, :direction])
    |> check_constraint(:to_room_id, name: :passages_from_room_and_to_room_must_differ)
  end

  defp validate_distinct_rooms(changeset) do
    from_room_id = get_field(changeset, :from_room_id)
    to_room_id = get_field(changeset, :to_room_id)

    if from_room_id && from_room_id == to_room_id do
      add_error(changeset, :to_room_id, "must differ from from_room_id")
    else
      changeset
    end
  end
end
