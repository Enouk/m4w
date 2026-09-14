defmodule M4w.Ops.Entity do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.Room

  schema "ops_entities" do
    field :name, :string
    field :kind, :string, default: "ai"
    field :agent_type, :string
    field :state, :string, default: "idle"
    field :attributes, :map, default: %{}

    belongs_to :room, Room

    timestamps(type: :utc_datetime)
  end

  @kinds ~w(ai human)
  @states ~w(idle working done)

  def changeset(entity, attrs) do
    entity
    |> cast(attrs, [:room_id, :name, :kind, :agent_type, :state, :attributes])
    |> validate_required([:room_id, :name, :kind, :state])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:state, @states)
    |> validate_length(:name, max: 255)
    |> validate_length(:agent_type, max: 255)
    |> foreign_key_constraint(:room_id)
  end
end
