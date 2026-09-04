defmodule M4wWeb.Plugs.OpsSpaceAccess do
  @moduledoc """
  Verifies the current user has access to the `:spaceId` path param and
  assigns the loaded `:space`. Must run after `M4wWeb.Plugs.OpsAuth`.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias M4w.Ops

  def init(opts), do: opts

  def call(%Plug.Conn{params: %{"spaceId" => space_id}} = conn, _opts) do
    user = conn.assigns.current_user

    if Ops.user_has_space_access?(user, space_id) do
      assign(conn, :space, Ops.get_space!(space_id))
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: %{code: "forbidden", message: "Ingen åtkomst till detta Space"}})
      |> halt()
    end
  end
end
