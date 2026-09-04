defmodule M4wWeb.Ops.SpaceJSON do
  alias M4w.Ops
  alias M4w.Ops.Space

  def index(%{spaces: spaces}), do: %{data: Enum.map(spaces, &data/1)}
  def show(%{space: space}), do: %{data: data(space)}

  def data(%Space{} = space) do
    %{
      id: to_string(space.id),
      name: space.name,
      address: space.address,
      category: space.category,
      goal: space.goal,
      status: space.status,
      activeCount: Ops.active_count(space)
    }
  end
end
