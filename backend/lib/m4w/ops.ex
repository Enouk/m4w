defmodule M4w.Ops do
  @moduledoc """
  The Ops context — backs the M4W REST API described in API-SPEC.md.

  Independent of `M4w.World` (which powers the separate MUD-builder LiveView);
  the two share no tables.
  """

  import Ecto.Query, warn: false

  alias M4w.Repo

  alias M4w.Ops.{
    Artifact,
    ComplianceCheck,
    Contact,
    Item,
    Mail,
    Meeting,
    OutboxMessage,
    Passage,
    Room,
    Space,
    User,
    UserSpace,
    Verification
  }

  @space_categories ["Marketing", "Sales", "Service", "HR", "Accounting", "Board"]

  def space_categories, do: @space_categories

  # ---------------- Auth ----------------

  @token_salt "ops_user_auth"

  def sign_user_token(%User{} = user) do
    Phoenix.Token.sign(M4wWeb.Endpoint, @token_salt, user.id)
  end

  def verify_user_token(token) do
    with {:ok, user_id} <-
           Phoenix.Token.verify(M4wWeb.Endpoint, @token_salt, token, max_age: :infinity) do
      case Repo.get(User, user_id) do
        %User{} = user -> {:ok, user}
        nil -> {:error, :not_found}
      end
    end
  end

  def get_user_by_email(email) do
    email = String.downcase(String.trim(email))

    User
    |> where([u], fragment("lower(?)", u.email) == ^email)
    |> Repo.one()
  end

  def get_user!(id), do: Repo.get!(User, id)

  def user_org_name(%User{org_id: nil}), do: nil
  def user_org_name(%User{} = user), do: Repo.preload(user, :org).org.name

  def user_space_ids(%User{} = user) do
    UserSpace
    |> where([us], us.user_id == ^user.id)
    |> select([us], us.space_id)
    |> Repo.all()
  end

  # ---------------- Spaces ----------------

  def list_spaces_for_user(%User{} = user) do
    space_ids = user_space_ids(user)

    Space
    |> where([s], s.id in ^space_ids)
    |> order_by([s], asc: s.name)
    |> Repo.all()
  end

  def get_space!(id), do: Repo.get!(Space, to_integer(id))

  def user_has_space_access?(%User{} = user, space_id) do
    space_id = to_integer(space_id)

    UserSpace
    |> where([us], us.user_id == ^user.id and us.space_id == ^space_id)
    |> Repo.exists?()
  end

  def active_count(%Space{id: space_id}) do
    Item
    |> join(:inner, [i], r in Room, on: i.room_id == r.id)
    |> where([i, r], r.space_id == ^space_id and i.state != "done")
    |> Repo.aggregate(:count)
  end

  def create_space_for_user(%User{} = user, attrs) do
    name = Map.get(attrs, "name") || Map.get(attrs, :name)
    category = Map.get(attrs, "category") || Map.get(attrs, :category)
    address = unique_address(name)

    Repo.transaction(fn ->
      {:ok, space} =
        %Space{}
        |> Space.changeset(%{name: name, address: address, category: category})
        |> Repo.insert()

      {:ok, _} =
        %UserSpace{}
        |> UserSpace.changeset(%{user_id: user.id, space_id: space.id})
        |> Repo.insert()

      space
    end)
  end

  defp unique_address(name) do
    base = slugify(name)
    do_unique_address(base, 0)
  end

  defp do_unique_address(base, attempt) do
    candidate = if attempt == 0, do: base <> "@m4w.ai", else: base <> "-#{attempt}@m4w.ai"

    if Repo.exists?(where(Space, [s], s.address == ^candidate)) do
      do_unique_address(base, attempt + 1)
    else
      candidate
    end
  end

  defp slugify(nil), do: "space"

  defp slugify(name) do
    slug =
      name
      |> String.downcase()
      |> String.normalize(:nfd)
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.replace(~r/[^\x00-\x7F]/u, "")
      |> String.trim("-")

    if slug == "", do: "space", else: slug
  end

  def update_space(%Space{} = space, attrs) do
    space |> Space.changeset(attrs) |> Repo.update()
  end

  def delete_space(%Space{} = space), do: Repo.delete(space)

  # ---------------- Rooms ----------------

  def list_rooms(%Space{id: space_id}) do
    Room
    |> where([r], r.space_id == ^space_id)
    |> order_by([r], asc: r.position, asc: r.id)
    |> Repo.all()
  end

  def get_room!(%Space{id: space_id}, id) do
    Room
    |> where([r], r.space_id == ^space_id and r.id == ^to_integer(id))
    |> Repo.one!()
  end

  def room_item_count(%Room{id: room_id}) do
    Item |> where([i], i.room_id == ^room_id) |> Repo.aggregate(:count)
  end

  def create_room(%Space{} = space, attrs) do
    next_position =
      (Room |> where([r], r.space_id == ^space.id) |> select([r], max(r.position)) |> Repo.one() ||
         -1) + 1

    attrs =
      %{"space_id" => space.id, "position" => next_position}
      |> Map.merge(normalize_room_attrs(attrs))

    %Room{} |> Room.changeset(attrs) |> Repo.insert()
  end

  def update_room(%Room{} = room, attrs) do
    room |> Room.changeset(normalize_room_attrs(attrs)) |> Repo.update()
  end

  defp normalize_room_attrs(attrs) do
    attrs
    |> Map.new(fn
      {"order", value} -> {"position", value}
      {"entity", %{"kind" => kind, "label" => label}} -> {"__entity__", {kind, label}}
      {key, value} -> {key, value}
    end)
    |> then(fn attrs ->
      case Map.pop(attrs, "__entity__") do
        {nil, attrs} ->
          attrs

        {{kind, label}, attrs} ->
          Map.merge(attrs, %{"entity_kind" => kind, "entity_label" => label})
      end
    end)
  end

  def delete_room(%Room{} = room), do: Repo.delete(room)

  # ---------------- Items ----------------

  def list_room_items(%Room{id: room_id}) do
    Item
    |> where([i], i.room_id == ^room_id)
    |> order_by([i], asc: i.id)
    |> Repo.all()
  end

  def get_item!(id) do
    Item
    |> Repo.get!(to_integer(id))
    |> Repo.preload([:room, :source_mail])
  end

  def item_passages(%Item{id: item_id}) do
    Passage
    |> where([p], p.item_id == ^item_id)
    |> order_by([p], desc: p.occurred_at)
    |> Repo.all()
  end

  def create_item(%Room{} = room, attrs) do
    attrs = Map.put(attrs, "room_id", room.id)
    %Item{} |> Item.changeset(attrs) |> Repo.insert()
  end

  def update_item(%Item{} = item, attrs) do
    item |> Item.changeset(attrs) |> Repo.update()
  end

  # ---------------- Passages ----------------

  def list_passages(%Space{id: space_id}) do
    Passage
    |> where([p], p.space_id == ^space_id)
    |> order_by([p], desc: p.occurred_at)
    |> Repo.all()
  end

  def create_passage(%Space{} = space, attrs) do
    attrs =
      attrs
      |> Map.put("space_id", space.id)
      |> Map.put_new("occurred_at", DateTime.utc_now() |> DateTime.truncate(:second))

    %Passage{} |> Passage.changeset(attrs) |> Repo.insert()
  end

  # ---------------- Artifacts ----------------

  def list_artifacts(%Space{id: space_id}) do
    Artifact
    |> where([a], a.space_id == ^space_id)
    |> order_by([a], desc: a.occurred_at)
    |> Repo.all()
  end

  def get_artifact!(id), do: Repo.get!(Artifact, to_integer(id))

  # ---------------- Mail / Inbox ----------------

  def list_space_inbox(%Space{id: space_id}) do
    Mail
    |> where(
      [m],
      m.space_id == ^space_id and m.purpose == "inbox" and m.status == "routed"
    )
    |> order_by([m], desc: m.occurred_at)
    |> Repo.all()
  end

  def get_mail!(id), do: Repo.get!(Mail, to_integer(id))

  def create_inbound_mail(attrs) do
    to = Map.get(attrs, "to")
    space = Space |> where([s], s.address == ^to) |> Repo.one()

    base = %{
      "from" => Map.get(attrs, "from"),
      "from_email" => Map.get(attrs, "fromEmail") || Map.get(attrs, "from_email"),
      "subject" => Map.get(attrs, "subject"),
      "body" => List.wrap(Map.get(attrs, "body")),
      "occurred_at" => parse_datetime(Map.get(attrs, "date")) || DateTime.utc_now(),
      "purpose" => "inbox"
    }

    classified =
      case space && list_rooms(space) do
        [] ->
          %{"status" => "unclassified", "reason" => "inga rum konfigurerade i spacet"}

        nil ->
          %{"status" => "unclassified", "reason" => "ingen matchande Space-adress"}

        [first_room | _] ->
          %{
            "status" => "routed",
            "space_id" => space.id,
            "room_id" => first_room.id,
            "confidence" => "medium"
          }
      end

    %Mail{} |> Mail.changeset(Map.merge(base, classified)) |> Repo.insert()
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  # ---------------- Context mails (design-time) ----------------

  def list_context_mails(%Space{id: space_id}) do
    Mail
    |> where([m], m.space_id == ^space_id and m.purpose == "context")
    |> order_by([m], desc: m.occurred_at)
    |> Repo.all()
  end

  def get_context_mail!(%Space{id: space_id}, mail_id) do
    Mail
    |> where(
      [m],
      m.space_id == ^space_id and m.purpose == "context" and m.id == ^to_integer(mail_id)
    )
    |> Repo.one!()
  end

  def update_context_mail(%Mail{} = mail, attrs) do
    mail |> Mail.changeset(attrs) |> Repo.update()
  end

  # ---------------- Design-mode generation (AI stand-in) ----------------

  def generate_rooms(%Space{} = space) do
    case list_rooms(space) do
      [] -> synthesize_rooms(space)
      rooms -> rooms
    end
  end

  defp synthesize_rooms(%Space{}) do
    [
      %{
        temp_id: "-1",
        name: "Inkorg",
        position: 0,
        entity_kind: "ai",
        entity_label: "AI",
        subgoal: "Nya mail klassificerade",
        key: "öppnar när typ ≠ okänd"
      },
      %{
        temp_id: "-2",
        name: "Behandling",
        position: 1,
        entity_kind: "mixed",
        entity_label: "AI + Människa",
        subgoal: "Ärendet berett och redo för beslut",
        key: "öppnar när underlag är komplett"
      },
      %{
        temp_id: "-3",
        name: "Godkännande",
        position: 2,
        entity_kind: "human",
        entity_label: "Ansvarig",
        subgoal: "Beslut fattat",
        key: "öppnar när godkänt"
      },
      %{
        temp_id: "-4",
        name: "Klart",
        position: 3,
        entity_kind: "ai",
        entity_label: "AI",
        subgoal: "Ärendet avslutat och arkiverat",
        key: "stängd terminalstation"
      }
    ]
  end

  # ---------------- Replay ----------------

  def list_replay_batch(%Space{id: space_id}) do
    Mail
    |> where([m], m.space_id == ^space_id and m.purpose == "replay_candidate")
    |> order_by([m], asc: m.id)
    |> Repo.all()
  end

  def run_replay(%Space{id: space_id}, mail_ids) do
    ids = Enum.map(mail_ids, &to_integer/1)

    mails =
      Mail
      |> where(
        [m],
        m.space_id == ^space_id and m.purpose == "replay_candidate" and m.id in ^ids
      )
      |> Repo.all()
      |> Repo.preload(:replay_room)
      |> Map.new(&{&1.id, &1})

    Enum.map(ids, fn id -> Map.get(mails, id) end)
    |> Enum.reject(&is_nil/1)
  end

  # ---------------- Outbox ----------------

  def get_outbox(%Space{id: space_id}) do
    messages =
      OutboxMessage
      |> where([o], o.space_id == ^space_id)
      |> order_by([o], desc: o.occurred_at)
      |> Repo.all()

    %{
      queued: Enum.filter(messages, &(&1.state == "queued")),
      sent: Enum.filter(messages, &(&1.state == "sent"))
    }
  end

  def get_outbox_message!(%Space{id: space_id}, id) do
    OutboxMessage
    |> where([o], o.space_id == ^space_id and o.id == ^to_integer(id))
    |> Repo.one!()
  end

  def approve_outbox_message(%OutboxMessage{} = message) do
    message
    |> OutboxMessage.changeset(%{
      "state" => "sent",
      "passage_note" => "Godkänd manuellt",
      "occurred_at" => DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  def update_outbox_message(%OutboxMessage{} = message, attrs) do
    message |> OutboxMessage.changeset(attrs) |> Repo.update()
  end

  def cancel_outbox_message(%OutboxMessage{} = message) do
    message |> OutboxMessage.changeset(%{"state" => "cancelled"}) |> Repo.update()
  end

  # ---------------- Contacts ----------------

  def list_space_contacts(%Space{id: space_id}) do
    Contact
    |> where([c], c.space_id == ^space_id)
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  def list_global_contacts(%User{} = user) do
    space_ids = user_space_ids(user)
    spaces = Space |> where([s], s.id in ^space_ids) |> Repo.all() |> Map.new(&{&1.id, &1})

    Contact
    |> where([c], c.space_id in ^space_ids)
    |> order_by([c], asc: c.name)
    |> Repo.all()
    |> Enum.reduce(%{}, fn contact, acc ->
      key =
        if contact.email && contact.email != "" do
          "e:" <> String.downcase(contact.email)
        else
          "n:#{contact.space_id}:#{contact.name}"
        end

      space = Map.get(spaces, contact.space_id)

      entry =
        Map.get(acc, key, %{
          name: contact.name,
          email: contact.email,
          group: contact.kind_group,
          roles: [],
          spaces: []
        })

      entry = %{
        entry
        | roles: Enum.uniq(entry.roles ++ [contact.role]),
          spaces: entry.spaces ++ [%{id: space.id, name: space.name, rooms: contact.rooms}]
      }

      Map.put(acc, key, entry)
    end)
    |> Map.values()
  end

  # ---------------- Global inbox & classification ----------------

  def global_inbox(%User{} = user) do
    space_ids = user_space_ids(user)

    routed =
      Mail
      |> where(
        [m],
        m.space_id in ^space_ids and m.purpose == "inbox" and m.status == "routed"
      )
      |> order_by([m], desc: m.occurred_at)
      |> Repo.all()

    unclassified =
      Mail
      |> where([m], is_nil(m.space_id) and m.purpose == "inbox" and m.status == "unclassified")
      |> order_by([m], desc: m.occurred_at)
      |> Repo.all()

    %{routed: routed, unclassified: unclassified}
  end

  def list_unclassified(%User{}) do
    Mail
    |> where([m], is_nil(m.space_id) and m.purpose == "inbox" and m.status == "unclassified")
    |> order_by([m], desc: m.occurred_at)
    |> Repo.all()
  end

  def assign_unclassified(%Mail{} = mail, nil) do
    mail |> Mail.changeset(%{"status" => "dismissed"}) |> Repo.update()
  end

  def assign_unclassified(%Mail{} = mail, space_id) do
    space = get_space!(space_id)

    room_id =
      case list_rooms(space) do
        [first | _] -> first.id
        [] -> nil
      end

    mail
    |> Mail.changeset(%{
      "status" => "routed",
      "space_id" => space.id,
      "room_id" => room_id,
      "confidence" => "high"
    })
    |> Repo.update()
  end

  # ---------------- Processes ----------------

  def list_processes(%User{} = user) do
    list_spaces_for_user(user)
    |> Enum.map(fn space -> {space, list_rooms(space)} end)
  end

  # ---------------- Meetings / Decisions ----------------

  def list_meetings(%Space{id: space_id}) do
    Meeting
    |> where([m], m.space_id == ^space_id)
    |> order_by([m], desc: m.occurred_at)
    |> Repo.all()
    |> Repo.preload(:decisions)
  end

  def get_meeting!(id) do
    Meeting |> Repo.get!(to_integer(id)) |> Repo.preload(:decisions)
  end

  def list_decisions(%Space{id: space_id}) do
    Meeting
    |> where([m], m.space_id == ^space_id)
    |> order_by([m], desc: m.occurred_at)
    |> Repo.all()
    |> Repo.preload(:decisions)
    |> Enum.flat_map(fn meeting ->
      Enum.map(meeting.decisions, &%{decision: &1, meeting: meeting})
    end)
  end

  # ---------------- Compliance / Verifications ----------------

  def list_compliance(%Space{id: space_id}) do
    ComplianceCheck
    |> where([c], c.space_id == ^space_id)
    |> order_by([c], asc: c.id)
    |> Repo.all()
  end

  def list_verifications(%Space{id: space_id}) do
    Verification
    |> where([v], v.space_id == ^space_id)
    |> order_by([v], desc: v.occurred_at)
    |> Repo.all()
  end

  # ---------------- Helpers ----------------

  defp to_integer(value) when is_integer(value), do: value
  defp to_integer(value) when is_binary(value), do: String.to_integer(value)
end
