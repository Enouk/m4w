defmodule M4wWeb.Ops.ActionJSON do
  alias M4w.Ops.Action

  def index(%{actions: actions}), do: %{data: Enum.map(actions, &data/1)}

  def show(%{action: action}), do: %{data: data(action)}

  def data(%Action{} = action) do
    %{
      id: to_string(action.id),
      title: action.title,
      assignee: action.assignee,
      assigneeRole: action.assignee_role,
      status: action.status,
      dueDate: action.due_at && DateTime.to_iso8601(action.due_at),
      meetingId: action.meeting_id && to_string(action.meeting_id),
      meetingTitle: meeting_title(action),
      meetingDate: meeting_date(action)
    }
  end

  defp meeting_title(%Action{meeting: %{title: title}}), do: title
  defp meeting_title(_), do: nil

  defp meeting_date(%Action{meeting: %{occurred_at: at}}), do: DateTime.to_iso8601(at)
  defp meeting_date(_), do: nil
end
