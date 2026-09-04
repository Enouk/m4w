defmodule M4wWeb.Ops.ArtifactJSON do
  alias M4w.Ops.Artifact

  def index(%{artifacts: artifacts}), do: %{data: Enum.map(artifacts, &data/1)}
  def show(%{artifact: artifact}), do: %{data: data(artifact)}

  def data(%Artifact{} = artifact) do
    %{
      id: to_string(artifact.id),
      spaceId: to_string(artifact.space_id),
      roomId: artifact.room_id && to_string(artifact.room_id),
      title: artifact.title,
      kind: artifact.kind,
      status: artifact.status,
      createdBy: artifact.created_by,
      size: artifact.size,
      url: artifact.url,
      date: DateTime.to_iso8601(artifact.occurred_at)
    }
  end
end
