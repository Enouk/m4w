defmodule M4w.Repo.Migrations.AddArtifactToOpsFinanceEntries do
  use Ecto.Migration

  def change do
    alter table(:ops_finance_entries) do
      add :artifact_id, references(:ops_artifacts, on_delete: :nilify_all)
    end

    create index(:ops_finance_entries, [:artifact_id])
  end
end
