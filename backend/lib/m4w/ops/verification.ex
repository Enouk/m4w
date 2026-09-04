defmodule M4w.Ops.Verification do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Room, Space}

  schema "ops_verifications" do
    field :ver, :string
    field :occurred_at, :utc_datetime
    field :supplier, :string
    field :amount, :string
    field :status, :string, default: "bokförd"
    field :archive_until, :string

    belongs_to :space, Space
    belongs_to :trace_from_room, Room
    belongs_to :trace_to_room, Room

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(bokförd exporterad avvikelse)

  def changeset(verification, attrs) do
    verification
    |> cast(attrs, [
      :space_id,
      :ver,
      :occurred_at,
      :supplier,
      :amount,
      :status,
      :archive_until,
      :trace_from_room_id,
      :trace_to_room_id
    ])
    |> validate_required([:space_id, :ver, :occurred_at])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:ver)
    |> foreign_key_constraint(:space_id)
  end
end
