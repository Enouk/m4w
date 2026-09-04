defmodule M4wWeb.Ops.MailJSON do
  alias M4w.Ops.Mail

  def index(%{mails: mails}), do: %{data: Enum.map(mails, &data/1)}
  def show(%{mail: mail}), do: %{data: data(mail)}

  def routed_and_unclassified(%{routed: routed, unclassified: unclassified}) do
    %{routed: Enum.map(routed, &data/1), unclassified: Enum.map(unclassified, &data/1)}
  end

  def replay_results(%{results: results}) do
    %{
      results:
        Enum.map(results, fn %Mail{} = mail ->
          %{
            mailId: to_string(mail.id),
            room: mail.replay_room && mail.replay_room.name,
            confidence: mail.replay_confidence,
            key: mail.replay_key,
            uncertain: mail.replay_uncertain
          }
        end)
    }
  end

  def data(%Mail{} = mail) do
    %{
      id: to_string(mail.id),
      spaceId: mail.space_id && to_string(mail.space_id),
      roomId: mail.room_id && to_string(mail.room_id),
      from: mail.from,
      fromEmail: mail.from_email,
      subject: mail.subject,
      date: DateTime.to_iso8601(mail.occurred_at),
      body: mail.body,
      confidence: mail.confidence,
      note: mail.note,
      reason: mail.reason,
      status: mail.status,
      use: mail.use
    }
  end
end
