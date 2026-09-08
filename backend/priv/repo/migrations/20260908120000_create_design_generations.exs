defmodule M4w.Repo.Migrations.CreateDesignGenerations do
  use Ecto.Migration

  def change do
    create table(:design_generations) do
      add :goal_id, references(:goals, on_delete: :delete_all), null: false
      add :space_id, references(:spaces, on_delete: :nilify_all)
      add :provider, :string, null: false
      add :model, :string, null: false
      add :status, :string, null: false, default: "ok"
      add :input_tokens, :integer, null: false, default: 0
      add :output_tokens, :integer, null: false, default: 0
      add :cost_usd, :decimal, null: false, default: 0
      add :error, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:design_generations, [:goal_id])
    create index(:design_generations, [:space_id])
  end
end
