defmodule M4wWeb.Ops.MailController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops

  def space_inbox(conn, _params) do
    render(conn, :index, mails: Ops.list_space_inbox(conn.assigns.space))
  end

  def show(conn, %{"mailId" => mail_id}) do
    mail = Ops.get_mail!(mail_id)

    if is_nil(mail.space_id) or
         Ops.user_has_space_access?(conn.assigns.current_user, mail.space_id) do
      render(conn, :show, mail: mail)
    else
      {:error, :forbidden}
    end
  end

  def inbound(conn, params) do
    with {:ok, mail} <- Ops.create_inbound_mail(params) do
      conn |> put_status(:created) |> render(:show, mail: mail)
    end
  end
end
