defmodule M4wWeb.RestAPI.SpaceJSON do
  alias M4w.World.{Goal, Space}

  def show(%{space: space}) do
    %{data: data(space)}
  end

  def error(%{errors: errors}) do
    %{errors: errors}
  end

  defp data(%Space{} = space) do
    %{
      id: space.id,
      name: space.name,
      description: space.description,
      metadata: space.metadata,
      goal: goal_data(space.goal),
      inserted_at: format_datetime(space.inserted_at),
      updated_at: format_datetime(space.updated_at)
    }
  end

  defp goal_data(%Goal{} = goal) do
    %{
      id: goal.id,
      title: goal.title,
      description: goal.description,
      status: goal.status,
      metadata: goal.metadata,
      inserted_at: format_datetime(goal.inserted_at),
      updated_at: format_datetime(goal.updated_at)
    }
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(datetime), do: DateTime.to_iso8601(datetime)
end
