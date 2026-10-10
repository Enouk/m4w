defmodule M4w.Ops.FinanceEntry do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Artifact, Meeting, Space}

  schema "ops_finance_entries" do
    field :title, :string
    field :kind, :string, default: "utgift"
    field :amount, :integer
    field :currency, :string, default: "SEK"
    field :note, :string
    field :status, :string, default: "att_godkanna"

    belongs_to :space, Space
    belongs_to :meeting, Meeting
    belongs_to :artifact, Artifact

    timestamps(type: :utc_datetime)
  end

  @kinds ~w(budget utgift intakt balansrakning resultatrakning arsredovisning)
  @statuses ~w(att_godkanna godkand avslagen)

  def kinds, do: @kinds
  def statuses, do: @statuses

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :space_id,
      :meeting_id,
      :artifact_id,
      :title,
      :kind,
      :amount,
      :currency,
      :note,
      :status
    ])
    |> validate_required([:space_id, :title, :amount])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:meeting_id)
    |> foreign_key_constraint(:artifact_id)
  end
end
