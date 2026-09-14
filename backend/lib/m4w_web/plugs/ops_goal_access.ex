defmodule M4wWeb.Plugs.OpsGoalAccess do
  @moduledoc """
  Verifies the current user has access to the `:goalId` path param and
  assigns the loaded `:goal`. Must run after `M4wWeb.Plugs.OpsAuth`.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias M4w.Ops

  def init(opts), do: opts

  def call(%Plug.Conn{params: %{"goalId" => goal_id}} = conn, _opts) do
    user = conn.assigns.current_user

    if Ops.user_has_goal_access?(user, goal_id) do
      assign(conn, :goal, Ops.get_goal!(goal_id))
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: %{code: "forbidden", message: "Ingen åtkomst till detta Goal"}})
      |> halt()
    end
  end
end
