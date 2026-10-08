defmodule M4wWeb.Ops.GoalController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, goals: Ops.list_goals_for_user(conn.assigns.current_user))
  end

  def create(conn, params) do
    with {:ok, goal} <- Ops.create_goal(conn.assigns.current_user, params) do
      conn |> put_status(:created) |> render(:show, goal: goal)
    end
  end

  def show(conn, _params), do: render(conn, :show, goal: conn.assigns.goal)

  def update(conn, params) do
    with {:ok, goal} <- Ops.update_goal(conn.assigns.goal, params) do
      render(conn, :show, goal: goal)
    end
  end

  def delete(conn, _params) do
    with {:ok, _} <- Ops.delete_goal(conn.assigns.goal) do
      send_resp(conn, :no_content, "")
    end
  end
end
