defmodule M4w.Repo.Migrations.CreateOpsTaxChecks do
  use Ecto.Migration

  def change do
    create table(:ops_tax_checks) do
      add :space_id, references(:ops_spaces, on_delete: :delete_all), null: false
      add :meeting_id, references(:ops_meetings, on_delete: :nilify_all)
      add :title, :text, null: false
      add :kind, :string, null: false, default: "moms"
      add :period, :string
      add :amount, :bigint
      add :currency, :string, null: false, default: "SEK"
      add :due_at, :utc_datetime
      add :note, :text
      add :status, :string, null: false, default: "att_betala"
      timestamps(type: :utc_datetime)
    end

    create index(:ops_tax_checks, [:space_id])
    create index(:ops_tax_checks, [:meeting_id])
  end
end
