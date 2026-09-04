defmodule M4w.Ops.Item do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Mail, Room}

  schema "ops_items" do
    field :title, :string
    field :meta, :string
    field :state, :string, default: "waiting"

    belongs_to :room, Room
    belongs_to :source_mail, Mail

    timestamps(type: :utc_datetime)
  end

  @states ~w(waiting running human live amber done)

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:room_id, :title, :meta, :state, :source_mail_id])
    |> validate_required([:room_id, :title])
    |> validate_inclusion(:state, @states)
    |> foreign_key_constraint(:room_id)
  end
end
