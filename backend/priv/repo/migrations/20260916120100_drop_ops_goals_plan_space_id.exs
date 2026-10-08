defmodule M4w.Repo.Migrations.DropOpsGoalsPlanSpaceId do
  use Ecto.Migration

  @moduledoc """
  Removes the "plan then confirm several Spaces" step: a Goal now gets
  exactly one Space directly on creation, so there's no separate plan Space
  to track.
  """

  def up do
    alter table(:ops_goals) do
      remove(:plan_space_id)
    end
  end

  def down do
    alter table(:ops_goals) do
      add(:plan_space_id, references(:ops_spaces, on_delete: :nilify_all))
    end
  end
end
