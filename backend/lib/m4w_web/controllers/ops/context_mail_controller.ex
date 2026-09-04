defmodule M4wWeb.Ops.ContextMailController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops
  alias M4wWeb.Ops.MailJSON

  def index(conn, _params) do
    conn
    |> put_view(json: MailJSON)
    |> render(:index, mails: Ops.list_context_mails(conn.assigns.space))
  end

  def update(conn, %{"mailId" => mail_id} = params) do
    mail = Ops.get_context_mail!(conn.assigns.space, mail_id)

    with {:ok, mail} <- Ops.update_context_mail(mail, params) do
      conn |> put_view(json: MailJSON) |> render(:show, mail: mail)
    end
  end
end
