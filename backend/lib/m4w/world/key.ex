defmodule M4w.World.Key do
  @moduledoc """
  A condition, permission, or quality requirement that can unlock doors.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.World.{Door, DoorKey, Passage, Space}

  schema "keys" do
    field :code, :string
    field :name, :string
    field :description, :string
    field :kind, :string, default: "condition"
    field :status, :string, default: "pending"
    field :criteria, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :space, Space
    has_many :door_keys, DoorKey
    has_many :used_passages, Passage, foreign_key: :used_key_id

    many_to_many :doors, Door,
      join_through: DoorKey,
      join_keys: [key_id: :id, door_id: :id]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(key, attrs) do
    key
    |> cast(attrs, [:space_id, :code, :name, :description, :kind, :status, :criteria, :metadata])
    |> validate_required([:space_id, :code, :name, :kind, :status])
    |> validate_length(:code, max: 255)
    |> validate_length(:name, max: 255)
    |> validate_length(:kind, max: 255)
    |> validate_length(:status, max: 255)
    |> foreign_key_constraint(:space_id)
    |> unique_constraint([:space_id, :code])
  end
end
