defmodule M4wWeb.Ops.ArtifactController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, artifacts: Ops.list_artifacts(conn.assigns.space))
  end

  def show(conn, %{"artifactId" => artifact_id}) do
    artifact = Ops.get_artifact!(artifact_id)

    if Ops.user_has_space_access?(conn.assigns.current_user, artifact.space_id) do
      render(conn, :show, artifact: artifact)
    else
      {:error, :forbidden}
    end
  end
end
