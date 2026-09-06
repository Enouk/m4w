defmodule M4w.Mail.StalwartMapper do
  @moduledoc """
  Translates a JMAP `Email` object (as returned by `Email/get`, with
  `fetchTextBodyValues: true`) into the attrs shape expected by
  `M4w.Ops.create_inbound_mail/1`.
  """

  def to_inbound_attrs(email) do
    from = first_address(email["from"])
    to = first_address(email["to"])

    %{
      "to" => to["email"],
      "from" => from["name"] || from["email"],
      "fromEmail" => from["email"],
      "subject" => email["subject"],
      "body" => body_paragraphs(email),
      "date" => email["receivedAt"],
      "attachments" => attachments(email)
    }
  end

  defp attachments(email) do
    (email["attachments"] || [])
    |> Enum.map(fn part ->
      %{
        "filename" => part["name"] || "attachment",
        "content_type" => part["type"],
        "size" => part["size"],
        "blob_id" => part["blobId"]
      }
    end)
  end

  defp first_address(nil), do: %{}
  defp first_address([]), do: %{}
  defp first_address([address | _]), do: address

  defp body_paragraphs(email) do
    body_values = email["bodyValues"] || %{}

    (email["textBody"] || [])
    |> Enum.map(fn part -> get_in(body_values, [part["partId"], "value"]) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.flat_map(&String.split(&1, ~r/\r?\n\s*\r?\n/))
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
