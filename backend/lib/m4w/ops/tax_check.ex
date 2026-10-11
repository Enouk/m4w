defmodule M4w.Ops.TaxCheck do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Meeting, Space}

  schema "ops_tax_checks" do
    field :title, :string
    field :kind, :string, default: "moms"
    field :period, :string
    field :amount, :integer
    field :currency, :string, default: "SEK"
    field :due_at, :utc_datetime
    field :note, :string
    field :status, :string, default: "att_betala"

    belongs_to :space, Space
    belongs_to :meeting, Meeting

    timestamps(type: :utc_datetime)
  end

  @kinds ~w(moms arbetsgivaravgifter preliminarskatt bolagsskatt skattekonto)
  @statuses ~w(betald att_betala forsenad)

  def kinds, do: @kinds
  def statuses, do: @statuses

  def changeset(check, attrs) do
    check
    |> cast(attrs, [
      :space_id,
      :meeting_id,
      :title,
      :kind,
      :period,
      :amount,
      :currency,
      :due_at,
      :note,
      :status
    ])
    |> validate_required([:space_id, :title])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:meeting_id)
  end
end
