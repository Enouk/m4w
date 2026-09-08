defmodule M4w.Repo.Migrations.GeneralizeDesignGenerations do
  use Ecto.Migration

  def change do
    alter table(:design_generations) do
      modify :goal_id, :bigint, null: true
      add :ops_space_id, references(:ops_spaces, on_delete: :nilify_all)
    end

    create index(:design_generations, [:ops_space_id])
  end
end
