defmodule M4w.Repo.Migrations.CreateOpsAgreementRevisions do
  use Ecto.Migration

  def change do
    create table(:ops_agreement_revisions) do
      add :space_id, references(:ops_spaces, on_delete: :delete_all), null: false
      add :artifact_id, references(:ops_artifacts, on_delete: :nilify_all)
      add :version, :string, null: false
      add :title, :text, null: false
      add :summary, :text
      add :changed_by, :string
      add :effective_at, :utc_datetime, null: false
      add :owners, {:array, :map}, null: false, default: []
      timestamps(type: :utc_datetime)
    end

    create index(:ops_agreement_revisions, [:space_id])
    create index(:ops_agreement_revisions, [:artifact_id])
  end
end
