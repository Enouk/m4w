defmodule M4w.Mail.StalwartClient do
  @moduledoc """
  Minimal JMAP (RFC 8620/8621) client for reading incoming mail out of
  Stalwart. Only what `M4w.Mail.StalwartPoller` needs: discover the API
  endpoint, find the Inbox, list unseen mail, and mark it seen.
  """

  @core_capability "urn:ietf:params:jmap:core"
  @mail_capability "urn:ietf:params:jmap:mail"

  def session(%{jmap_url: jmap_url} = config) do
    case Req.get(jmap_url <> "/.well-known/jmap", auth: basic_auth(config)) do
      {:ok, %{status: 200, body: body}} ->
        account_id = get_in(body, ["primaryAccounts", @mail_capability])

        if account_id && body["apiUrl"] do
          {:ok, %{api_url: local_api_url(jmap_url, body["apiUrl"]), account_id: account_id}}
        else
          {:error, {:no_mail_account, body}}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Stalwart reports `apiUrl` using its configured public hostname (e.g.
  # `https://mail.example.com/jmap/`), which usually isn't the address we can
  # actually reach it at from inside Docker. Only the path is meaningful to
  # us — keep talking to the same host:port we were configured with.
  defp local_api_url(jmap_url, api_url), do: jmap_url <> URI.parse(api_url).path

  def inbox_mailbox_id(api_url, account_id, config) do
    method_calls = [
      ["Mailbox/query", %{accountId: account_id, filter: %{role: "inbox"}}, "m0"]
    ]

    with {:ok, [["Mailbox/query", %{"ids" => ids}, "m0"]]} <- call(api_url, method_calls, config) do
      case ids do
        [id | _] -> {:ok, id}
        [] -> {:error, :no_inbox_mailbox}
      end
    else
      {:ok, other} -> {:error, {:unexpected_response, other}}
      error -> error
    end
  end

  def unseen_inbox_emails(api_url, account_id, mailbox_id, config) do
    method_calls = [
      [
        "Email/query",
        %{
          accountId: account_id,
          filter: %{inMailbox: mailbox_id, notKeyword: "$seen"},
          sort: [%{property: "receivedAt", isAscending: true}],
          limit: 50
        },
        "q"
      ],
      [
        "Email/get",
        %{
          accountId: account_id,
          "#ids": %{resultOf: "q", name: "Email/query", path: "/ids"},
          properties: ["from", "to", "subject", "receivedAt", "textBody", "bodyValues"],
          fetchTextBodyValues: true
        },
        "g"
      ]
    ]

    with {:ok, responses} <- call(api_url, method_calls, config),
         %{"list" => emails} <-
           Enum.find_value(responses, fn
             ["Email/get", result, "g"] -> result
             _ -> nil
           end) do
      {:ok, emails}
    else
      nil -> {:error, :no_email_get_response}
      error -> error
    end
  end

  def mark_seen(api_url, account_id, email_ids, config) do
    update =
      Map.new(email_ids, fn id -> {id, %{"keywords/$seen" => true}} end)

    method_calls = [
      ["Email/set", %{accountId: account_id, update: update}, "s"]
    ]

    with {:ok, [["Email/set", _result, "s"]]} <- call(api_url, method_calls, config) do
      :ok
    else
      {:ok, other} -> {:error, {:unexpected_response, other}}
      error -> error
    end
  end

  defp call(api_url, method_calls, config) do
    body = %{using: [@core_capability, @mail_capability], methodCalls: method_calls}

    case Req.post(api_url, json: body, auth: basic_auth(config)) do
      {:ok, %{status: 200, body: %{"methodResponses" => responses}}} -> {:ok, responses}
      {:ok, %{status: status, body: body}} -> {:error, {:unexpected_status, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp basic_auth(%{jmap_user: user, jmap_password: password}),
    do: {:basic, "#{user}:#{password}"}
end
