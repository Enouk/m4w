defmodule M4wWeb.Plugs.OpsAuth do
  @moduledoc """
  Requires a valid `Authorization: Bearer <token>` header, assigning
  `:current_user` on success. Used by every `/api/v1` route except
  `POST /auth/login`.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias M4w.Ops

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- Ops.verify_user_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{code: "unauthorized", message: "Ej inloggad"}})
        |> halt()
    end
  end
end
