defmodule M4w.World.Entity do
  @moduledoc """
  Something that can exist in a space and optionally be placed in a room.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.World.{Room, Space}

  schema "entities" do
    field :name, :string
    field :description, :string
    field :kind, :string, default: "thing"
    field :state, :string, default: "idle"
    field :attributes, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :space, Space
    belongs_to :room, Room

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(entity, attrs) do
    entity
    |> cast(attrs, [
      :space_id,
      :room_id,
      :name,
      :description,
      :kind,
      :state,
      :attributes,
      :metadata
    ])
    |> validate_required([:space_id, :name, :kind, :state])
    |> validate_length(:name, max: 255)
    |> validate_length(:kind, max: 255)
    |> validate_length(:state, max: 255)
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:room_id)
  end
end
