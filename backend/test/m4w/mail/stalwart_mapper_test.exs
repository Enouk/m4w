defmodule M4w.Mail.StalwartMapperTest do
  use ExUnit.Case, async: true

  alias M4w.Mail.StalwartMapper

  test "maps a JMAP Email object into create_inbound_mail/1 attrs" do
    email = %{
      "id" => "M123",
      "from" => [%{"name" => "Anna Andersson", "email" => "anna@example.com"}],
      "to" => [%{"name" => "Sales", "email" => "sales@m4w.local"}],
      "subject" => "Fråga om offert",
      "receivedAt" => "2026-09-06T10:15:00Z",
      "textBody" => [%{"partId" => "1", "type" => "text/plain"}],
      "bodyValues" => %{
        "1" => %{
          "value" => "Hej!\n\nKan ni skicka en offert?\n\nMvh Anna",
          "isTruncated" => false
        }
      }
    }

    assert StalwartMapper.to_inbound_attrs(email) == %{
             "to" => "sales@m4w.local",
             "from" => "Anna Andersson",
             "fromEmail" => "anna@example.com",
             "subject" => "Fråga om offert",
             "body" => ["Hej!", "Kan ni skicka en offert?", "Mvh Anna"],
             "date" => "2026-09-06T10:15:00Z"
           }
  end

  test "falls back to the email address when there is no display name" do
    email = %{
      "from" => [%{"name" => nil, "email" => "anna@example.com"}],
      "to" => [%{"name" => nil, "email" => "sales@m4w.local"}],
      "subject" => "Hej",
      "receivedAt" => "2026-09-06T10:15:00Z",
      "textBody" => [],
      "bodyValues" => %{}
    }

    attrs = StalwartMapper.to_inbound_attrs(email)

    assert attrs["from"] == "anna@example.com"
    assert attrs["body"] == []
  end

  test "handles missing from/to addresses without raising" do
    email = %{
      "from" => nil,
      "to" => nil,
      "subject" => "Hej",
      "receivedAt" => "2026-09-06T10:15:00Z",
      "textBody" => nil,
      "bodyValues" => nil
    }

    assert StalwartMapper.to_inbound_attrs(email) == %{
             "to" => nil,
             "from" => nil,
             "fromEmail" => nil,
             "subject" => "Hej",
             "body" => [],
             "date" => "2026-09-06T10:15:00Z"
           }
  end
end
