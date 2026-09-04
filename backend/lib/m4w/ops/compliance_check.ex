defmodule M4w.Ops.ComplianceCheck do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.Space

  schema "ops_compliance_checks" do
    field :title, :string
    field :ref, :string
    field :status, :string, default: "pagar"
    field :description, :string
    field :state, :string

    belongs_to :space, Space

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(uppfyllt avvikelse pagar)

  def changeset(check, attrs) do
    check
    |> cast(attrs, [:space_id, :title, :ref, :status, :description, :state])
    |> validate_required([:space_id, :title])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:space_id)
  end
end
