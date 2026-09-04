defmodule M4w.World.Artifact do
  @moduledoc """
  A traceable work product created or carried through the world.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.World.{Passage, Room, Space}

  schema "artifacts" do
    field :key, :string
    field :name, :string
    field :description, :string
    field :kind, :string, default: "work_product"
    field :status, :string, default: "draft"
    field :content, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :space, Space
    belongs_to :room, Room
    has_many :passages, Passage

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [
      :space_id,
      :room_id,
      :key,
      :name,
      :description,
      :kind,
      :status,
      :content,
      :metadata
    ])
    |> validate_required([:space_id, :key, :name, :kind, :status])
    |> validate_length(:key, max: 255)
    |> validate_length(:name, max: 255)
    |> validate_length(:kind, max: 255)
    |> validate_length(:status, max: 255)
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:room_id)
    |> unique_constraint([:space_id, :key])
  end
end
