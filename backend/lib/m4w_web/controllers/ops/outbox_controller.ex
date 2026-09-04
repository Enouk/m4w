defmodule M4wWeb.Ops.OutboxController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :show, outbox: Ops.get_outbox(conn.assigns.space))
  end

  def approve(conn, %{"messageId" => message_id}) do
    message = Ops.get_outbox_message!(conn.assigns.space, message_id)

    with {:ok, message} <- Ops.approve_outbox_message(message) do
      render(conn, :message, message: message)
    end
  end

  def update(conn, %{"messageId" => message_id} = params) do
    message = Ops.get_outbox_message!(conn.assigns.space, message_id)

    with {:ok, message} <- Ops.update_outbox_message(message, params) do
      render(conn, :message, message: message)
    end
  end

  def cancel(conn, %{"messageId" => message_id}) do
    message = Ops.get_outbox_message!(conn.assigns.space, message_id)

    with {:ok, _} <- Ops.cancel_outbox_message(message) do
      send_resp(conn, :no_content, "")
    end
  end
end
