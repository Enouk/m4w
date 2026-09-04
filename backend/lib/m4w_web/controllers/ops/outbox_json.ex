defmodule M4wWeb.Ops.OutboxJSON do
  alias M4w.Ops.OutboxMessage

  def show(%{outbox: outbox}) do
    %{
      data: %{
        queued: Enum.map(outbox.queued, &data/1),
        sent: Enum.map(outbox.sent, &data/1)
      }
    }
  end

  def message(%{message: message}), do: %{data: data(message)}

  def data(%OutboxMessage{} = message) do
    %{
      id: to_string(message.id),
      spaceId: to_string(message.space_id),
      state: message.state,
      from: message.from,
      to: message.to,
      subject: message.subject,
      preview: message.preview,
      statusNote: message.status_note,
      passageNote: message.passage_note,
      time: DateTime.to_iso8601(message.occurred_at)
    }
  end
end
