defmodule M4wWeb.Ops.FinanceJSON do
  alias M4w.Ops.FinanceEntry

  def index(%{entries: entries}), do: %{data: Enum.map(entries, &data/1)}

  def data(%FinanceEntry{} = entry) do
    %{
      id: to_string(entry.id),
      title: entry.title,
      kind: entry.kind,
      amount: entry.amount,
      currency: entry.currency,
      note: entry.note,
      status: entry.status,
      meetingId: entry.meeting_id && to_string(entry.meeting_id),
      meetingTitle: meeting_title(entry),
      meetingDate: meeting_date(entry),
      document: document(entry)
    }
  end

  defp document(%FinanceEntry{artifact: %{} = a}) do
    %{id: to_string(a.id), title: a.title, kind: a.kind, size: a.size, url: a.url}
  end

  defp document(_), do: nil

  defp meeting_title(%FinanceEntry{meeting: %{title: title}}), do: title
  defp meeting_title(_), do: nil

  defp meeting_date(%FinanceEntry{meeting: %{occurred_at: at}}), do: DateTime.to_iso8601(at)
  defp meeting_date(_), do: nil
end
