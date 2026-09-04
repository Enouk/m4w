defmodule M4w.World.Goal do
  @moduledoc """
  A goal is the top-level objective that frames one or more spaces.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.World.Space

  schema "goals" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "active"
    field :metadata, :map, default: %{}

    has_many :spaces, Space

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [:title, :description, :status, :metadata])
    |> validate_required([:title, :status])
    |> validate_length(:title, max: 255)
    |> validate_length(:status, max: 255)
  end
end
