defmodule M4wWeb.Ops.GlobalInboxController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops
  alias M4w.Ops.Mail
  alias M4wWeb.Ops.MailJSON

  def index(conn, _params) do
    %{routed: routed, unclassified: unclassified} = Ops.global_inbox(conn.assigns.current_user)

    conn
    |> put_view(json: MailJSON)
    |> render(:routed_and_unclassified, routed: routed, unclassified: unclassified)
  end

  def unclassified(conn, _params) do
    conn
    |> put_view(json: MailJSON)
    |> render(:index, mails: Ops.list_unclassified(conn.assigns.current_user))
  end

  def assign(conn, %{"mailId" => mail_id} = params) do
    mail = Ops.get_mail!(mail_id)
    space_id = Map.get(params, "spaceId")

    with :ok <- authorize_target(conn, space_id),
         {:ok, mail} <- Ops.assign_unclassified(mail, space_id) do
      conn |> put_view(json: MailJSON) |> render(:show, mail: mail)
    end
  end

  def delete(conn, %{"mailId" => mail_id}) do
    mail = Ops.get_mail!(mail_id)

    with :ok <- ensure_unclassified(mail),
         {:ok, _mail} <- Ops.delete_mail(mail) do
      send_resp(conn, :no_content, "")
    end
  end

  defp ensure_unclassified(%Mail{status: "unclassified"}), do: :ok
  defp ensure_unclassified(_mail), do: {:error, :forbidden}

  defp authorize_target(_conn, nil), do: :ok

  defp authorize_target(conn, space_id) do
    if Ops.user_has_space_access?(conn.assigns.current_user, space_id) do
      :ok
    else
      {:error, :forbidden}
    end
  end
end
