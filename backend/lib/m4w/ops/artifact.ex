defmodule M4w.Ops.Artifact do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Room, Space}

  schema "ops_artifacts" do
    field :title, :string
    field :kind, :string
    field :status, :string
    field :created_by, :string
    field :size, :string
    field :url, :string
    field :occurred_at, :utc_datetime

    belongs_to :space, Space
    belongs_to :room, Room

    timestamps(type: :utc_datetime)
  end

  @kinds ~w(PDF DOCX CSV SIE)

  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [
      :space_id,
      :room_id,
      :title,
      :kind,
      :status,
      :created_by,
      :size,
      :url,
      :occurred_at
    ])
    |> validate_required([:space_id, :title, :kind, :status, :occurred_at])
    |> validate_inclusion(:kind, @kinds)
    |> foreign_key_constraint(:space_id)
  end
end
