defmodule M4w.Ops.Outbox do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{OutboxMessage, Space}

  schema "ops_outboxes" do
    belongs_to :space, Space
    has_many :messages, OutboxMessage

    timestamps(type: :utc_datetime)
  end

  def changeset(outbox, attrs) do
    outbox
    |> cast(attrs, [:space_id])
    |> validate_required([:space_id])
    |> unique_constraint(:space_id)
    |> foreign_key_constraint(:space_id)
  end
end
