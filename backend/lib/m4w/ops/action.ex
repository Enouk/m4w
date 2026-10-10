defmodule M4w.Ops.Action do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Meeting, Space}

  schema "ops_actions" do
    field :title, :string
    field :assignee, :string
    field :assignee_role, :string
    field :due_at, :utc_datetime
    field :status, :string, default: "att_gora"

    belongs_to :space, Space
    belongs_to :meeting, Meeting

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(att_gora pagar klar)

  def statuses, do: @statuses

  def changeset(action, attrs) do
    action
    |> cast(attrs, [:space_id, :meeting_id, :title, :assignee, :assignee_role, :due_at, :status])
    |> validate_required([:space_id, :title, :assignee])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:meeting_id)
  end
end
