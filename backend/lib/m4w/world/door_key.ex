defmodule M4w.World.DoorKey do
  @moduledoc """
  A key requirement for opening or passing through a door.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.World.{Door, Key}

  schema "door_keys" do
    field :requirement_kind, :string, default: "required"
    field :metadata, :map, default: %{}

    belongs_to :door, Door
    belongs_to :key, Key

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(door_key, attrs) do
    door_key
    |> cast(attrs, [:door_id, :key_id, :requirement_kind, :metadata])
    |> validate_required([:door_id, :key_id, :requirement_kind])
    |> validate_length(:requirement_kind, max: 255)
    |> foreign_key_constraint(:door_id)
    |> foreign_key_constraint(:key_id)
    |> unique_constraint([:door_id, :key_id])
  end
end
