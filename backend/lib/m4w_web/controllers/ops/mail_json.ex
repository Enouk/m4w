defmodule M4wWeb.Ops.MailJSON do
  alias M4w.Ops.{Mail, MailAttachment}

  def index(%{mails: mails}), do: %{data: Enum.map(mails, &data/1)}
  def show(%{mail: mail}), do: %{data: data(mail)}

  def routed_and_unclassified(%{routed: routed, unclassified: unclassified}) do
    %{routed: Enum.map(routed, &data/1), unclassified: Enum.map(unclassified, &data/1)}
  end

  def replay_results(%{results: results}) do
    %{
      results:
        Enum.map(results, fn %Mail{} = mail ->
          room = mail.replay_room || mail.room

          %{
            mailId: to_string(mail.id),
            room: room && room.name,
            confidence: mail.replay_confidence || confidence_pct(mail.confidence),
            key: mail.replay_key,
            uncertain: mail.replay_uncertain || mail.confidence == "low"
          }
        end)
    }
  end

  defp confidence_pct("high"), do: 95
  defp confidence_pct("medium"), do: 70
  defp confidence_pct("low"), do: 40
  defp confidence_pct(_), do: nil

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
      use: mail.use,
      attachments: Enum.map(loaded_attachments(mail), &attachment_data/1)
    }
  end

  defp loaded_attachments(%Mail{attachments: %Ecto.Association.NotLoaded{}}), do: []
  defp loaded_attachments(%Mail{attachments: attachments}), do: attachments

  defp attachment_data(%MailAttachment{} = attachment) do
    %{
      id: to_string(attachment.id),
      filename: attachment.filename,
      contentType: attachment.content_type,
      size: attachment.size,
      url: "/api/v1/mail/#{attachment.mail_id}/attachments/#{attachment.id}"
    }
  end
end
