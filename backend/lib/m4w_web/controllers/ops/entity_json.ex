defmodule M4wWeb.Ops.EntityJSON do
  alias M4w.Ops.Entity

  def index(%{entities: entities}), do: %{data: Enum.map(entities, &data/1)}
  def show(%{entity: entity}), do: %{data: data(entity)}

  def data(%Entity{} = entity) do
    %{
      id: to_string(entity.id),
      roomId: to_string(entity.room_id),
      name: entity.name,
      kind: entity.kind,
      agentType: entity.agent_type,
      state: entity.state,
      attributes: entity.attributes
    }
  end
end
