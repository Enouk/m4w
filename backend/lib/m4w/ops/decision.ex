defmodule M4w.Ops.Decision do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.Meeting

  schema "ops_decisions" do
    field :text, :string
    field :outcome, :string
    field :votes, :string

    belongs_to :meeting, Meeting

    timestamps(type: :utc_datetime)
  end

  def changeset(decision, attrs) do
    decision
    |> cast(attrs, [:meeting_id, :text, :outcome, :votes])
    |> validate_required([:meeting_id, :text])
    |> foreign_key_constraint(:meeting_id)
  end
end
