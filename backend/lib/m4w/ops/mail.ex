defmodule M4w.Ops.Mail do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Room, Space}

  schema "ops_mails" do
    field :from, :string
    field :from_email, :string
    field :subject, :string
    field :body, {:array, :string}, default: []
    field :occurred_at, :utc_datetime
    field :confidence, :string
    field :note, :string
    field :reason, :string
    field :status, :string, default: "unclassified"
    field :purpose, :string, default: "inbox"
    field :use, :boolean

    field :replay_confidence, :integer
    field :replay_key, :string
    field :replay_uncertain, :boolean, default: false

    belongs_to :space, Space
    belongs_to :room, Room
    belongs_to :replay_room, Room

    timestamps(type: :utc_datetime)
  end

  @confidences ~w(high medium low)
  @statuses ~w(routed unclassified dismissed)
  @purposes ~w(inbox context replay_candidate)

  def changeset(mail, attrs) do
    mail
    |> cast(attrs, [
      :space_id,
      :room_id,
      :from,
      :from_email,
      :subject,
      :body,
      :occurred_at,
      :confidence,
      :note,
      :reason,
      :status,
      :purpose,
      :use,
      :replay_room_id,
      :replay_confidence,
      :replay_key,
      :replay_uncertain
    ])
    |> validate_required([:from, :subject, :occurred_at])
    |> validate_inclusion(:confidence, @confidences)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:purpose, @purposes)
  end
end
