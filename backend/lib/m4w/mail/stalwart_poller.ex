defmodule M4w.Mail.StalwartPoller do
  @moduledoc """
  Periodically pulls unseen mail out of the Stalwart Inbox via JMAP and feeds
  it into `M4w.Ops.create_inbound_mail/1`, which routes it to a Space by its
  `to` address exactly like the `POST /api/v1/inbound-mail` webhook does.

  Only started when `:stalwart, :jmap_url` is configured — see
  `M4w.Application`.
  """

  use GenServer

  require Logger

  alias M4w.Mail.{StalwartClient, StalwartMapper}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    config = %{
      jmap_url: Application.get_env(:m4w, :stalwart)[:jmap_url],
      jmap_user: Application.get_env(:m4w, :stalwart)[:jmap_user],
      jmap_password: Application.get_env(:m4w, :stalwart)[:jmap_password],
      poll_interval_ms: Application.get_env(:m4w, :stalwart)[:poll_interval_ms]
    }

    send(self(), :poll)
    {:ok, %{config: config, api_url: nil, account_id: nil, download_url: nil, mailbox_id: nil}}
  end

  @impl true
  def handle_info(:poll, state) do
    state =
      state
      |> ensure_session()
      |> ensure_inbox_mailbox_id()
      |> poll_inbox()

    Process.send_after(self(), :poll, state.config.poll_interval_ms)
    {:noreply, state}
  end

  defp ensure_session(%{api_url: api_url, account_id: account_id} = state)
       when is_binary(api_url) and is_binary(account_id),
       do: state

  defp ensure_session(state) do
    case StalwartClient.session(state.config) do
      {:ok, %{api_url: api_url, account_id: account_id, download_url: download_url}} ->
        %{state | api_url: api_url, account_id: account_id, download_url: download_url}

      {:error, reason} ->
        Logger.warning("StalwartPoller: could not establish a JMAP session: #{inspect(reason)}")
        state
    end
  end

  defp ensure_inbox_mailbox_id(%{api_url: nil} = state), do: state

  defp ensure_inbox_mailbox_id(%{mailbox_id: mailbox_id} = state) when is_binary(mailbox_id),
    do: state

  defp ensure_inbox_mailbox_id(state) do
    case StalwartClient.inbox_mailbox_id(state.api_url, state.account_id, state.config) do
      {:ok, mailbox_id} ->
        %{state | mailbox_id: mailbox_id}

      {:error, reason} ->
        Logger.warning("StalwartPoller: could not find the Inbox mailbox: #{inspect(reason)}")
        # The session may be stale (e.g. server restarted) — rediscover next tick.
        %{state | api_url: nil, account_id: nil, download_url: nil}
    end
  end

  defp poll_inbox(%{api_url: nil} = state), do: state
  defp poll_inbox(%{mailbox_id: nil} = state), do: state

  defp poll_inbox(state) do
    case StalwartClient.unseen_inbox_emails(
           state.api_url,
           state.account_id,
           state.mailbox_id,
           state.config
         ) do
      {:ok, emails} ->
        seen_ids = Enum.flat_map(emails, &import_email(&1, state))

        if seen_ids != [] do
          case StalwartClient.mark_seen(state.api_url, state.account_id, seen_ids, state.config) do
            :ok ->
              :ok

            {:error, reason} ->
              Logger.warning("StalwartPoller: failed to mark mail seen: #{inspect(reason)}")
          end
        end

        state

      {:error, reason} ->
        Logger.warning("StalwartPoller: failed to fetch unseen mail: #{inspect(reason)}")
        %{state | api_url: nil, account_id: nil, download_url: nil, mailbox_id: nil}
    end
  end

  defp import_email(email, state) do
    attrs =
      email
      |> StalwartMapper.to_inbound_attrs()
      |> Map.update!("attachments", fn attachments ->
        attachments |> Enum.map(&download_attachment(&1, state)) |> Enum.reject(&is_nil/1)
      end)

    case M4w.Ops.create_inbound_mail(attrs) do
      {:ok, _mail} ->
        [email["id"]]

      {:error, changeset} ->
        Logger.error(
          "StalwartPoller: failed to import mail #{email["id"]}: #{inspect(changeset)}"
        )

        []
    end
  end

  defp download_attachment(
         %{"blob_id" => blob_id} = attachment,
         %{download_url: download_url, account_id: account_id, config: config}
       )
       when is_binary(blob_id) and is_binary(download_url) do
    case StalwartClient.download_blob(
           download_url,
           account_id,
           blob_id,
           attachment["filename"],
           attachment["content_type"],
           config
         ) do
      {:ok, data} ->
        Map.put(attachment, "data", data)

      {:error, reason} ->
        Logger.warning(
          "StalwartPoller: failed to download attachment #{blob_id}: #{inspect(reason)}"
        )

        nil
    end
  end

  defp download_attachment(_attachment, _state), do: nil
end
