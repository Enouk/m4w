defmodule M4wWeb.Ops.MeetingController do
  use M4wWeb, :controller

  action_fallback M4wWeb.Ops.FallbackController

  alias M4w.Ops

  def index(conn, _params) do
    render(conn, :index, meetings: Ops.list_meetings(conn.assigns.space))
  end

  def show(conn, %{"meetingId" => meeting_id}) do
    meeting = Ops.get_meeting!(meeting_id)

    if Ops.user_has_space_access?(conn.assigns.current_user, meeting.space_id) do
      render(conn, :show, meeting: meeting)
    else
      {:error, :forbidden}
    end
  end
end
