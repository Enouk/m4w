defmodule M4wWeb.Ops.ProcessJSON do
  alias M4wWeb.Ops.{RoomJSON, SpaceJSON}

  def index(%{processes: processes}) do
    %{
      data:
        Enum.map(processes, fn {space, rooms} ->
          SpaceJSON.data(space) |> Map.put(:rooms, Enum.map(rooms, &RoomJSON.data/1))
        end)
    }
  end
end
