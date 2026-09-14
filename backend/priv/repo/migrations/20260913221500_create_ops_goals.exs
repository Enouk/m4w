defmodule M4w.Repo.Migrations.CreateOpsGoals do
  use Ecto.Migration

  def change do
    create table(:ops_goals) do
      add(:user_id, references(:ops_users, on_delete: :delete_all), null: false)
      add(:title, :string, null: false)
      add(:description, :text, default: "")
      add(:status, :string, null: false, default: "active")
      add(:plan_space_id, references(:ops_spaces, on_delete: :nilify_all))
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_goals, [:user_id]))

    alter table(:ops_spaces) do
      add(:goal_id, references(:ops_goals, on_delete: :delete_all))
    end

    create(index(:ops_spaces, [:goal_id]))
  end
end
