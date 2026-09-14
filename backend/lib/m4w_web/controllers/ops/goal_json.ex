defmodule M4wWeb.Ops.GoalJSON do
  alias M4w.Ops.Goal
  alias M4wWeb.Ops.SpaceJSON

  def index(%{goals: goals}), do: %{data: Enum.map(goals, &data/1)}
  def show(%{goal: goal}), do: %{data: data(goal)}

  def plan(%{spaces: drafts}) do
    %{
      spaces:
        Enum.map(drafts, fn draft ->
          %{id: draft.temp_id, name: draft.name, subgoal: draft.subgoal}
        end)
    }
  end

  def data(%Goal{} = goal) do
    %{
      id: to_string(goal.id),
      title: goal.title,
      description: goal.description,
      status: goal.status,
      planSpaceId: goal.plan_space_id && to_string(goal.plan_space_id),
      spaces: goal_spaces(goal)
    }
  end

  defp goal_spaces(%Goal{spaces: %Ecto.Association.NotLoaded{}}), do: []
  defp goal_spaces(%Goal{spaces: spaces}), do: Enum.map(spaces, &SpaceJSON.data/1)
end
