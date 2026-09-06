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

  def download_attachment(conn, %{"mailId" => mail_id, "attachmentId" => attachment_id}) do
    mail = Ops.get_mail!(mail_id)

    if is_nil(mail.space_id) or
         Ops.user_has_space_access?(conn.assigns.current_user, mail.space_id) do
      case Ops.get_mail_attachment(mail, attachment_id) do
        nil ->
          {:error, :not_found}

        attachment ->
          conn
          |> put_resp_content_type(attachment.content_type || "application/octet-stream")
          |> put_resp_header("content-disposition", content_disposition(attachment.filename))
          |> send_resp(200, attachment.data)
      end
    else
      {:error, :forbidden}
    end
  end

  defp content_disposition(filename) do
    safe = String.replace(filename || "attachment", ["\"", "\r", "\n"], "_")
    encoded = URI.encode(safe, &URI.char_unreserved?/1)
    ~s(attachment; filename="#{safe}"; filename*=UTF-8''#{encoded})
  end
end
