defmodule M4w.Repo.Migrations.AddAgendaToOpsMeetings do
  use Ecto.Migration

  def change do
    alter table(:ops_meetings) do
      add :agenda_id, references(:ops_artifacts, on_delete: :nilify_all)
    end

    create index(:ops_meetings, [:agenda_id])
  end
end
