defmodule M4w.Ops.AgreementRevision do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Artifact, Space}

  # One revision of the shareholders' agreement. `owners` is the cap table as it
  # stands after the revision: [%{"name" => ..., "shares" => integer}].
  schema "ops_agreement_revisions" do
    field :version, :string
    field :title, :string
    field :summary, :string
    field :changed_by, :string
    field :effective_at, :utc_datetime
    field :owners, {:array, :map}, default: []

    belongs_to :space, Space
    belongs_to :artifact, Artifact

    timestamps(type: :utc_datetime)
  end

  def changeset(revision, attrs) do
    revision
    |> cast(attrs, [
      :space_id,
      :artifact_id,
      :version,
      :title,
      :summary,
      :changed_by,
      :effective_at,
      :owners
    ])
    |> validate_required([:space_id, :version, :title, :effective_at])
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:artifact_id)
  end
end
