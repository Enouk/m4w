defmodule M4wWeb.Ops.DecisionJSON do
  alias M4w.Ops.Decision

  def index(%{decisions: decisions}) do
    %{
      data:
        Enum.map(decisions, fn %{decision: decision, meeting: meeting} ->
          data(decision)
          |> Map.put(:meetingTitle, meeting.title)
          |> Map.put(:date, DateTime.to_iso8601(meeting.occurred_at))
        end)
    }
  end

  def data(%Decision{} = decision) do
    %{
      id: to_string(decision.id),
      meetingId: to_string(decision.meeting_id),
      text: decision.text,
      outcome: decision.outcome,
      votes: decision.votes
    }
  end
end
