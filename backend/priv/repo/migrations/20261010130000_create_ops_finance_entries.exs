defmodule M4w.Repo.Migrations.CreateOpsFinanceEntries do
  use Ecto.Migration

  def change do
    create table(:ops_finance_entries) do
      add :space_id, references(:ops_spaces, on_delete: :delete_all), null: false
      add :meeting_id, references(:ops_meetings, on_delete: :nilify_all)
      add :title, :text, null: false
      add :kind, :string, null: false, default: "utgift"
      add :amount, :bigint, null: false
      add :currency, :string, null: false, default: "SEK"
      add :note, :text
      add :status, :string, null: false, default: "att_godkanna"
      timestamps(type: :utc_datetime)
    end

    create index(:ops_finance_entries, [:space_id])
    create index(:ops_finance_entries, [:meeting_id])
  end
end
