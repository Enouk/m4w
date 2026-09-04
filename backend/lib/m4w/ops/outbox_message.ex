defmodule M4w.Ops.OutboxMessage do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.Space

  schema "ops_outbox_messages" do
    field :state, :string, default: "queued"
    field :from, :string
    field :to, :string
    field :subject, :string
    field :preview, :string
    field :status_note, :string
    field :passage_note, :string
    field :occurred_at, :utc_datetime

    belongs_to :space, Space

    timestamps(type: :utc_datetime)
  end

  @states ~w(queued sent cancelled)

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :space_id,
      :state,
      :from,
      :to,
      :subject,
      :preview,
      :status_note,
      :passage_note,
      :occurred_at
    ])
    |> validate_required([:space_id, :from, :to, :subject, :occurred_at])
    |> validate_inclusion(:state, @states)
    |> foreign_key_constraint(:space_id)
  end
end
