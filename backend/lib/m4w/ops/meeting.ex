defmodule M4w.Ops.Meeting do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Decision, Space}

  schema "ops_meetings" do
    field :title, :string
    field :occurred_at, :utc_datetime
    field :status, :string, default: "planerat"
    field :location, :string
    field :attendees, {:array, :map}, default: []

    belongs_to :space, Space
    has_many :decisions, Decision

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(planerat genomfört pagar)

  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [:space_id, :title, :occurred_at, :status, :location, :attendees])
    |> validate_required([:space_id, :title, :occurred_at])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:space_id)
  end
end
