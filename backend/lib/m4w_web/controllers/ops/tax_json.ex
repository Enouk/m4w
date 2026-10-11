defmodule M4wWeb.Ops.TaxJSON do
  alias M4w.Ops.TaxCheck

  def index(%{checks: checks}), do: %{data: Enum.map(checks, &data/1)}

  def data(%TaxCheck{} = check) do
    %{
      id: to_string(check.id),
      title: check.title,
      kind: check.kind,
      period: check.period,
      amount: check.amount,
      currency: check.currency,
      dueAt: check.due_at && DateTime.to_iso8601(check.due_at),
      note: check.note,
      status: check.status,
      meetingId: check.meeting_id && to_string(check.meeting_id)
    }
  end
end
