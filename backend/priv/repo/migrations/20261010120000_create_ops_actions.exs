defmodule M4w.Repo.Migrations.CreateOpsActions do
  use Ecto.Migration

  def change do
    create table(:ops_actions) do
      add :space_id, references(:ops_spaces, on_delete: :delete_all), null: false
      add :meeting_id, references(:ops_meetings, on_delete: :nilify_all)
      add :title, :text, null: false
      add :assignee, :string, null: false
      add :assignee_role, :string
      add :due_at, :utc_datetime
      add :status, :string, null: false, default: "att_gora"
      timestamps(type: :utc_datetime)
    end

    create index(:ops_actions, [:space_id])
    create index(:ops_actions, [:meeting_id])
  end
end
