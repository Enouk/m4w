defmodule M4wWeb.Ops.AuthController do
  use M4wWeb, :controller

  alias M4w.Ops
  alias M4wWeb.Ops.UserJSON

  def login(conn, %{"email" => email} = _params) when is_binary(email) do
    case Ops.get_user_by_email(email) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{code: "unauthorized", message: "Okänd e-postadress"}})

      user ->
        json(conn, %{token: Ops.sign_user_token(user), user: UserJSON.data(user)})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{code: "validation_error", message: "email krävs"}})
  end

  def logout(conn, _params), do: send_resp(conn, :no_content, "")

  def me(conn, _params), do: json(conn, UserJSON.data(conn.assigns.current_user))
end
