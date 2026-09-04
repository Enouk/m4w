defmodule M4w.World.Space do
  @moduledoc """
  A bounded world or map that belongs to a goal.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.World.{Artifact, Door, Entity, Goal, Key, Passage, Room}

  schema "spaces" do
    field :name, :string
    field :description, :string
    field :metadata, :map, default: %{}

    belongs_to :goal, Goal
    has_many :rooms, Room
    has_many :doors, Door
    has_many :keys, Key
    has_many :entities, Entity
    has_many :artifacts, Artifact
    has_many :passages, Passage

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(space, attrs) do
    space
    |> cast(attrs, [:goal_id, :name, :description, :metadata])
    |> validate_required([:goal_id, :name])
    |> validate_length(:name, max: 255)
    |> foreign_key_constraint(:goal_id)
    |> unique_constraint([:goal_id, :name])
  end
end
