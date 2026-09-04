defmodule M4wWeb.Ops.ContactController do
  use M4wWeb, :controller

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, contacts: Ops.list_space_contacts(conn.assigns.space))
  end

  def global_index(conn, _params) do
    render(conn, :global_index, contacts: Ops.list_global_contacts(conn.assigns.current_user))
  end
end
