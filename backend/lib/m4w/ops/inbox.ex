defmodule M4w.Ops.Inbox do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Mail, Space}

  schema "ops_inboxes" do
    belongs_to :space, Space
    has_many :mails, Mail

    timestamps(type: :utc_datetime)
  end

  def changeset(inbox, attrs) do
    inbox
    |> cast(attrs, [:space_id])
    |> validate_required([:space_id])
    |> unique_constraint(:space_id)
    |> foreign_key_constraint(:space_id)
  end
end
