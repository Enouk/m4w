defmodule M4wWeb.Ops.MeetingJSON do
  alias M4w.Ops.Meeting

  def index(%{meetings: meetings}), do: %{data: Enum.map(meetings, &data/1)}
  def show(%{meeting: meeting}), do: %{data: data(meeting)}

  def data(%Meeting{} = meeting) do
    %{
      id: to_string(meeting.id),
      spaceId: to_string(meeting.space_id),
      title: meeting.title,
      date: DateTime.to_iso8601(meeting.occurred_at),
      status: meeting.status,
      location: meeting.location,
      attendees: meeting.attendees,
      decisions: Enum.map(meeting.decisions, &M4wWeb.Ops.DecisionJSON.data/1)
    }
  end
end
