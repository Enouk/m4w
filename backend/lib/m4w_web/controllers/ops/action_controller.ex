defmodule M4wWeb.Ops.ActionController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, actions: Ops.list_actions(conn.assigns.space))
  end

  def update(conn, %{"actionId" => action_id} = params) do
    action = Ops.get_action!(conn.assigns.space, action_id)

    with {:ok, action} <- Ops.update_action(action, Map.drop(params, ["space_id", "meeting_id"])) do
      render(conn, :show, action: Ops.get_action!(conn.assigns.space, action.id))
    end
  end
end
