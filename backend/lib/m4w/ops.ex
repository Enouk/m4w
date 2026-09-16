defmodule M4w.Ops do
  @moduledoc """
  The Ops context — backs the M4W REST API described in API-SPEC.md.

  Independent of `M4w.World` (which powers the separate MUD-builder LiveView)
  — the two share no domain tables. Both do share `M4w.Design`'s
  `design_generations` audit log, which attributes rows to either a World
  Goal or an Ops Space.
  """

  import Ecto.Query, warn: false

  alias M4w.Repo

  alias M4w.Ops.{
    Artifact,
    ComplianceCheck,
    Contact,
    Entity,
    Goal,
    GoalPlanSchema,
    Inbox,
    Item,
    Mail,
    MailAttachment,
    Meeting,
    Outbox,
    OutboxMessage,
    Passage,
    Room,
    RoomBlueprintSchema,
    Space,
    User,
    UserSpace,
    Verification
  }

  @space_categories ["Marketing", "Sales", "Service", "HR", "Accounting", "Board", "Code"]

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

  # ---------------- Goals ----------------
  #
  # A Goal frames one or more Spaces created to reach it. Creating a Goal
  # immediately spins up a "Plan" Space whose `goal` field holds the
  # description that gets fed to the LLM in `generate_goal_plan/2` — the
  # "plan mode" step that drafts the sibling Spaces needed to reach the
  # goal. Drafts are never auto-persisted; `confirm_goal_plan/3` creates the
  # real Spaces once the user approves the draft, mirroring the
  # draft-then-confirm pattern used for Room generation below.

  def list_goals_for_user(%User{} = user) do
    Goal
    |> where([g], g.user_id == ^user.id)
    |> order_by([g], desc: g.inserted_at)
    |> Repo.all()
  end

  def get_goal!(id) do
    Goal
    |> Repo.get!(to_integer(id))
    |> Repo.preload(spaces: from(s in Space, order_by: [asc: s.id]))
  end

  def user_has_goal_access?(%User{} = user, goal_id) do
    Goal
    |> where([g], g.id == ^to_integer(goal_id) and g.user_id == ^user.id)
    |> Repo.exists?()
  end

  def create_goal_with_plan(%User{} = user, attrs) do
    title = Map.get(attrs, "title") || Map.get(attrs, :title)
    description = Map.get(attrs, "description") || Map.get(attrs, :description) || ""

    Repo.transaction(fn ->
      {:ok, goal} =
        %Goal{}
        |> Goal.changeset(%{user_id: user.id, title: title, description: description})
        |> Repo.insert()

      {:ok, plan_space} =
        create_space_for_user(user, %{
          "name" => "Plan",
          "category" => "Code",
          "goal" => description
        })

      {:ok, plan_space} =
        plan_space |> Space.changeset(%{goal_id: goal.id}) |> Repo.update()

      {:ok, goal} =
        goal |> Goal.changeset(%{plan_space_id: plan_space.id}) |> Repo.update()

      %{goal | spaces: [plan_space]}
    end)
  end

  def update_goal(%Goal{} = goal, attrs) do
    goal |> Goal.changeset(attrs) |> Repo.update()
  end

  def delete_goal(%Goal{} = goal), do: Repo.delete(goal)

  def generate_goal_plan(%Goal{} = goal) do
    request = goal_plan_request(goal)
    opts = [ops_space_id: goal.plan_space_id]

    case M4w.Design.generate_blueprint(request, opts) do
      {:ok, blueprint, _generation} ->
        case blueprint_to_goal_space_drafts(blueprint) do
          [] -> synthesize_goal_plan(goal)
          drafts -> drafts
        end

      {:error, _reason, _generation} ->
        synthesize_goal_plan(goal)
    end
  end

  defp goal_plan_request(%Goal{} = goal) do
    %{
      system_prompt: goal_plan_system_prompt(),
      user_prompt: goal_plan_user_prompt(goal),
      tool_name: "emit_goal_plan",
      tool_description: "Emit the drafted set of Spaces needed to reach this Goal.",
      schema: GoalPlanSchema.schema()
    }
  end

  defp goal_plan_system_prompt do
    """
    Du designar en plan för vilka Spaces som behövs för att nå ett mål i \
    "Code for work". Varje Space är ett eget arbetsområde med sitt eget \
    delmål (subgoal) som tillsammans, i ordning, uppfyller huvudmålet.

    Föreslå minst ett och högst åtta Spaces. Skriv allt på svenska.

    Svara enbart genom att anropa verktyget — inga fritextsvar.
    """
  end

  defp goal_plan_user_prompt(%Goal{} = goal) do
    """
    Mål: #{goal.title}

    Beskrivning: #{if goal.description in [nil, ""], do: "(ingen beskrivning angiven)", else: goal.description}
    """
  end

  defp blueprint_to_goal_space_drafts(%{"spaces" => spaces})
       when is_list(spaces) and spaces != [] do
    spaces
    |> Enum.with_index()
    |> Enum.map(fn {space, index} ->
      %{temp_id: "-#{index + 1}", name: space["name"], subgoal: space["subgoal"]}
    end)
  end

  defp blueprint_to_goal_space_drafts(_blueprint), do: []

  defp synthesize_goal_plan(%Goal{}) do
    [%{temp_id: "-1", name: "Implementation", subgoal: "Målet är genomfört"}]
  end

  def confirm_goal_plan(%Goal{} = goal, %User{} = user, spaces_attrs)
      when is_list(spaces_attrs) do
    Repo.transaction(fn ->
      spaces =
        Enum.map(spaces_attrs, fn attrs ->
          name = Map.get(attrs, "name") || Map.get(attrs, :name)
          subgoal = Map.get(attrs, "subgoal") || Map.get(attrs, :subgoal) || ""

          {:ok, space} =
            create_space_for_user(user, %{"name" => name, "category" => "Code", "goal" => subgoal})

          {:ok, space} = space |> Space.changeset(%{goal_id: goal.id}) |> Repo.update()
          space
        end)

      if goal.plan_space_id do
        goal.plan_space_id
        |> get_space!()
        |> Space.changeset(%{status: "done"})
        |> Repo.update!()
      end

      spaces
    end)
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
    goal = Map.get(attrs, "goal") || Map.get(attrs, :goal)
    address = unique_address(name)

    Repo.transaction(fn ->
      {:ok, space} =
        %Space{}
        |> Space.changeset(%{name: name, address: address, category: category, goal: goal})
        |> Repo.insert()

      {:ok, _} =
        %UserSpace{}
        |> UserSpace.changeset(%{user_id: user.id, space_id: space.id})
        |> Repo.insert()

      {:ok, _} = %Inbox{} |> Inbox.changeset(%{space_id: space.id}) |> Repo.insert()
      {:ok, _} = %Outbox{} |> Outbox.changeset(%{space_id: space.id}) |> Repo.insert()

      space
    end)
  end

  def get_inbox!(%Space{id: space_id}) do
    Inbox |> Repo.get_by!(space_id: space_id)
  end

  def get_outbox_entity!(%Space{id: space_id}) do
    Outbox |> Repo.get_by!(space_id: space_id)
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

    {legacy_entity, attrs} = Map.pop(attrs, "entity")

    with {:ok, room} <- %Room{} |> Room.changeset(attrs) |> Repo.insert() do
      sync_room_entities_from_legacy_param(room, legacy_entity)
      {:ok, room}
    end
  end

  def update_room(%Room{} = room, attrs) do
    attrs = normalize_room_attrs(attrs)
    {legacy_entity, attrs} = Map.pop(attrs, "entity")

    with {:ok, room} <- room |> Room.changeset(attrs) |> Repo.update() do
      sync_room_entities_from_legacy_param(room, legacy_entity)
      {:ok, room}
    end
  end

  defp normalize_room_attrs(attrs) do
    Map.new(attrs, fn
      {"order", value} -> {"position", value}
      {key, value} -> {key, value}
    end)
  end

  # Transitional: frontend/mail's design-view still sends a room-level
  # `entity: %{"kind" => ..., "label" => ...}` param (see DesignView.jsx
  # `persistRooms`) instead of managing Entities directly. Translate it into
  # real Ops.Entity row(s) so that flow keeps working unchanged. Remove once
  # frontend/mail is migrated to the entities API.
  defp sync_room_entities_from_legacy_param(_room, nil), do: :ok

  defp sync_room_entities_from_legacy_param(%Room{} = room, %{"kind" => kind} = legacy) do
    case list_room_entities(room) do
      [] -> create_legacy_entities(room, kind, legacy["label"])
      entities -> update_primary_entity_label(entities, legacy["label"])
    end
  end

  defp sync_room_entities_from_legacy_param(_room, _legacy), do: :ok

  # A "mixed" room gets a single combined label from the design LLM (e.g.
  # "AI + Designer") describing both participants together — giving that
  # same string as the `name` of both Entity rows makes them look like
  # duplicates in the map (same text, two icons). The AI side gets a plain
  # "AI" name; the human side keeps the descriptive label.
  defp create_legacy_entities(room, "mixed", label) do
    create_entity(room, %{
      "kind" => "ai",
      "agent_type" => "claude_code",
      "name" => "AI"
    })

    create_entity(room, %{"kind" => "human", "name" => label || "Person"})
  end

  defp create_legacy_entities(room, "human", label) do
    create_entity(room, %{"kind" => "human", "name" => label || "Person"})
  end

  defp create_legacy_entities(room, _kind, label) do
    create_entity(room, %{
      "kind" => "ai",
      "agent_type" => "claude_code",
      "name" => label || "Agent"
    })
  end

  defp update_primary_entity_label(_entities, nil), do: :ok

  defp update_primary_entity_label(entities, label) do
    primary = Enum.find(entities, &(&1.kind == "ai")) || List.first(entities)
    update_entity(primary, %{"name" => label})
  end

  def delete_room(%Room{} = room), do: Repo.delete(room)

  # ---------------- Entities ----------------

  def list_room_entities(%Room{id: room_id}) do
    Entity
    |> where([e], e.room_id == ^room_id)
    |> order_by([e], asc: e.id)
    |> Repo.all()
  end

  def get_entity!(id) do
    Entity
    |> Repo.get!(to_integer(id))
    |> Repo.preload(:room)
  end

  def create_entity(%Room{} = room, attrs) do
    attrs = Map.put(attrs, "room_id", room.id)
    %Entity{} |> Entity.changeset(attrs) |> Repo.insert()
  end

  def update_entity(%Entity{} = entity, attrs) do
    entity |> Entity.changeset(attrs) |> Repo.update()
  end

  def delete_entity(%Entity{} = entity), do: Repo.delete(entity)

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

  # ---------------- Agent runner ----------------
  #
  # Items sitting in `state: "waiting"` inside a Room worked by an `ai`
  # Entity are runnable — M4w.Ops.AgentRunner polls this to find work.

  def list_ai_runnable_items(limit \\ 5) do
    Item
    |> join(:inner, [i], r in Room, on: i.room_id == r.id)
    |> join(:inner, [i, r], e in Entity, on: e.room_id == r.id and e.kind == "ai")
    |> where([i], i.state == "waiting")
    |> distinct([i], i.id)
    |> order_by([i], asc: i.id)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload(room: [:entities, :space])
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
    |> Repo.preload(:attachments)
  end

  def get_mail!(id), do: Mail |> Repo.get!(to_integer(id)) |> Repo.preload(:attachments)

  def get_mail_attachment(%Mail{id: mail_id}, attachment_id) do
    MailAttachment
    |> where([a], a.mail_id == ^mail_id and a.id == ^to_integer(attachment_id))
    |> Repo.one()
  end

  def delete_mail(%Mail{} = mail), do: Repo.delete(mail)

  def create_inbound_mail(attrs) do
    to = Map.get(attrs, "to")
    space = Space |> where([s], s.address == ^to) |> Repo.one()
    attachments = Map.get(attrs, "attachments") || []

    base = %{
      "from" => Map.get(attrs, "from"),
      "from_email" => Map.get(attrs, "fromEmail") || Map.get(attrs, "from_email"),
      "subject" => Map.get(attrs, "subject"),
      "body" => List.wrap(Map.get(attrs, "body")),
      "occurred_at" => parse_datetime(Map.get(attrs, "date")) || DateTime.utc_now(),
      "purpose" => "inbox"
    }

    classified =
      case space do
        nil ->
          %{"status" => "unclassified", "reason" => "ingen matchande Space-adress"}

        %Space{} ->
          first_room =
            case list_rooms(space) do
              [first_room | _] -> first_room
              [] -> nil
            end

          %{
            "space_id" => space.id,
            "inbox_id" => get_inbox!(space).id,
            "status" => "routed",
            "room_id" => first_room && first_room.id,
            "confidence" => first_room && "medium",
            "room_name" => first_room && first_room.name
          }
      end

    Repo.transaction(fn ->
      mail_attrs = Map.merge(base, Map.delete(classified, "room_name"))

      case %Mail{} |> Mail.changeset(mail_attrs) |> Repo.insert() do
        {:ok, mail} ->
          Enum.each(attachments, fn attachment ->
            %MailAttachment{}
            |> MailAttachment.changeset(Map.put(attachment, "mail_id", mail.id))
            |> Repo.insert!()
          end)

          if space,
            do:
              upsert_contact_from_mail(
                space,
                base["from"],
                base["from_email"],
                classified["room_name"]
              )

          Repo.preload(mail, :attachments, force: true)

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp upsert_contact_from_mail(_space, _from_name, nil, _room_name), do: :ok
  defp upsert_contact_from_mail(_space, _from_name, "", _room_name), do: :ok

  defp upsert_contact_from_mail(space, from_name, from_email, room_name) do
    email = String.trim(from_email)

    existing =
      Contact
      |> where(
        [c],
        c.space_id == ^space.id and fragment("lower(?)", c.email) == ^String.downcase(email)
      )
      |> Repo.one()

    case existing do
      nil ->
        %Contact{}
        |> Contact.changeset(%{
          "space_id" => space.id,
          "name" => (from_name && from_name != "" && from_name) || email,
          "email" => email,
          "kind_group" => "extern",
          "rooms" => List.wrap(room_name)
        })
        |> Repo.insert()

      %Contact{} = contact ->
        if room_name && room_name not in contact.rooms do
          contact
          |> Contact.changeset(%{"rooms" => contact.rooms ++ [room_name]})
          |> Repo.update()
        else
          {:ok, contact}
        end
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  # ---------------- Context mails (design-time) ----------------
  #
  # Design mode uses the same inbox as Kör — every mail routed to the space
  # is available as generation context, whether or not it's tied to a Room.

  def list_context_mails(%Space{} = space), do: list_space_inbox(space)

  def get_context_mail!(%Space{id: space_id}, mail_id) do
    Mail
    |> where(
      [m],
      m.space_id == ^space_id and m.purpose == "inbox" and m.status == "routed" and
        m.id == ^to_integer(mail_id)
    )
    |> Repo.one!()
    |> Repo.preload(:attachments)
  end

  def update_context_mail(%Mail{} = mail, attrs) do
    mail |> Mail.changeset(attrs) |> Repo.update()
  end

  # ---------------- Design-mode generation ----------------
  #
  # Asks M4w.Design to design a Room pipeline from the Space's goal (plus
  # any mail marked `use: true` as context). Never persists — the frontend
  # diffs the returned drafts against what's persisted and upserts via the
  # regular Room CRUD endpoints (see DesignView.jsx `saveToRun`). Falls back
  # to the fixed `synthesize_rooms/1` template if the provider fails, isn't
  # configured, or returns something unusable.

  def generate_rooms(%Space{} = space, opts \\ []) do
    case list_rooms(space) do
      [] -> ai_generate_rooms(space, opts)
      rooms -> rooms
    end
  end

  defp ai_generate_rooms(%Space{} = space, opts) do
    request = design_request(space)
    opts = Keyword.put(opts, :ops_space_id, space.id)

    case M4w.Design.generate_blueprint(request, opts) do
      {:ok, blueprint, _generation} ->
        case blueprint_to_room_drafts(blueprint) do
          [] -> synthesize_rooms(space)
          drafts -> drafts
        end

      {:error, _reason, _generation} ->
        synthesize_rooms(space)
    end
  end

  defp design_request(%Space{} = space) do
    %{
      system_prompt: design_system_prompt(),
      user_prompt: design_user_prompt(space),
      tool_name: "emit_room_blueprint",
      tool_description: "Emit the designed Room pipeline for this Space.",
      schema: RoomBlueprintSchema.schema()
    }
  end

  defp design_system_prompt do
    """
    Du designar en pipeline av Rooms för ett Space i "MUD for Work": varje \
    Room är en station där en typ av arbete sker innan det flyttas vidare. \
    Rummen bildar en ordnad kedja, först till sist. Varje Room har ett namn, \
    vem eller vad som arbetar där (entity_kind: ai/human/mixed + \
    entity_label), ett subgoal (vad som måste vara sant för att rummets \
    arbete ska anses klart) och en key (ett kort, läsbart villkor för när \
    rummet öppnas, t.ex. "öppnar när underlag är komplett").

    Designa minst tre och högst åtta rum som tillsammans bildar en \
    sammanhängande, meningsfull pipeline för målet och mailkontexten du får. \
    Skriv allt på svenska.

    Svara enbart genom att anropa verktyget — inga fritextsvar.
    """
  end

  defp design_user_prompt(%Space{} = space) do
    goal = if space.goal in [nil, ""], do: "(inget mål angivet ännu)", else: space.goal

    """
    Space: #{space.name}

    Mål: #{goal}

    Mailkontext:
    #{design_mail_context(space)}
    """
  end

  defp design_mail_context(%Space{} = space) do
    space
    |> list_context_mails()
    |> Enum.filter(& &1.use)
    |> case do
      [] -> "Ingen mailkontext vald."
      mails -> mails |> Enum.map(&design_mail_context_line/1) |> Enum.join("\n")
    end
  end

  defp design_mail_context_line(%Mail{} = mail) do
    "- Från #{mail.from}: \"#{mail.subject}\" — #{mail_body_snippet(mail)}"
  end

  defp mail_body_snippet(%Mail{} = mail) do
    mail.body |> Enum.join(" ") |> String.slice(0, 500)
  end

  defp blueprint_to_room_drafts(%{"rooms" => rooms}) when is_list(rooms) and rooms != [] do
    rooms
    |> Enum.with_index()
    |> Enum.map(fn {room, index} ->
      %{
        temp_id: "-#{index + 1}",
        name: room["name"],
        position: index,
        entity_kind: room["entity_kind"],
        entity_label: room["entity_label"],
        subgoal: room["subgoal"],
        key: room["key"]
      }
    end)
  end

  defp blueprint_to_room_drafts(_blueprint), do: []

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
  #
  # Classifies each candidate mail against the Space's *already designed*
  # Room pipeline (see generate_rooms/2) via M4w.Design, and persists the
  # result onto the mail's replay_* fields. If there are no Rooms yet, or
  # the provider returns nothing usable, mails are left untouched —
  # MailJSON.replay_results/1 falls back to the mail's naive inbound
  # routing (room/confidence) in that case.

  def list_replay_batch(%Space{id: space_id}) do
    Mail
    |> where([m], m.space_id == ^space_id)
    |> where(^replay_candidate_condition())
    |> order_by([m], asc: m.id)
    |> Repo.all()
  end

  def run_replay(%Space{} = space, mail_ids, opts \\ []) do
    ids = Enum.map(mail_ids, &to_integer/1)

    mails_by_id =
      Mail
      |> where([m], m.space_id == ^space.id and m.id in ^ids)
      |> where(^replay_candidate_condition())
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    ordered_mails = ids |> Enum.map(&Map.get(mails_by_id, &1)) |> Enum.reject(&is_nil/1)

    updated_mails =
      case {ordered_mails, list_rooms(space)} do
        {[], _} -> ordered_mails
        {_, []} -> ordered_mails
        {_, rooms} -> classify_mails(space, rooms, ordered_mails, opts)
      end

    Repo.preload(updated_mails, [:replay_room, :room], force: true)
  end

  defp replay_candidate_condition do
    dynamic(
      [m],
      m.purpose == "replay_candidate" or (m.purpose == "inbox" and m.status == "routed")
    )
  end

  defp classify_mails(%Space{} = space, rooms, mails, opts) do
    request = classify_request(space, rooms, mails)
    opts = Keyword.put(opts, :ops_space_id, space.id)

    case M4w.Design.generate_blueprint(request, opts) do
      {:ok, blueprint, _generation} -> apply_replay_assignments(blueprint, mails, rooms)
      {:error, _reason, _generation} -> mails
    end
  end

  defp classify_request(%Space{} = space, rooms, mails) do
    %{
      system_prompt: classify_system_prompt(),
      user_prompt: classify_user_prompt(space, rooms, mails),
      tool_name: "emit_mail_classifications",
      tool_description: "Classify each mail into one of the Space's existing Rooms.",
      schema: classify_schema(rooms, mails)
    }
  end

  defp classify_system_prompt do
    """
    Du klassificerar inkommande mail mot en redan designad pipeline av Rooms \
    för detta Space. Varje Room har ett namn, ett subgoal (vad som måste vara \
    sant för att rummets arbete ska anses klart) och en key (ett kort, \
    läsbart villkor för när rummet öppnas).

    För varje mail du får: välj vilket Room det hör hemma i just nu, ange hur \
    säker du är (confidence 0-100), en kort key-text som förklarar villkoret \
    eller varför, och sätt uncertain: true om inget Room passar bra.

    Svara enbart genom att anropa verktyget — inga fritextsvar.
    """
  end

  defp classify_user_prompt(%Space{} = space, rooms, mails) do
    """
    Space: #{space.name}

    Rum-pipeline:
    #{Enum.map_join(rooms, "\n", &room_context_line/1)}

    Mail att klassificera:
    #{Enum.map_join(mails, "\n", &classify_mail_context_line/1)}
    """
  end

  defp room_context_line(%Room{} = room) do
    "- #{room.name}: #{room.subgoal} (öppnar när: #{room.key})"
  end

  defp classify_mail_context_line(%Mail{} = mail) do
    "- [#{mail.id}] Från #{mail.from}: \"#{mail.subject}\" — #{mail_body_snippet(mail)}"
  end

  defp classify_schema(rooms, mails) do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => ["assignments"],
      "properties" => %{
        "assignments" => %{
          "type" => "array",
          "description" => "One classification per mail being replayed.",
          "minItems" => 1,
          "items" => %{
            "type" => "object",
            "additionalProperties" => false,
            "required" => ["mail_id", "room", "confidence", "uncertain"],
            "properties" => %{
              "mail_id" => %{
                "type" => "string",
                "enum" => Enum.map(mails, &to_string(&1.id))
              },
              "room" => %{
                "type" => "string",
                "enum" => Enum.map(rooms, & &1.name)
              },
              "confidence" => %{
                "type" => "integer",
                "minimum" => 0,
                "maximum" => 100
              },
              "key" => %{
                "type" => "string",
                "description" => "Short condition/reason for this classification."
              },
              "uncertain" => %{
                "type" => "boolean",
                "description" => "true if no Room fits this mail well."
              }
            }
          }
        }
      }
    }
  end

  defp apply_replay_assignments(%{"assignments" => assignments}, mails, rooms)
       when is_list(assignments) do
    rooms_by_name = Map.new(rooms, &{&1.name, &1})
    assignments_by_mail_id = Map.new(assignments, &{to_string(&1["mail_id"]), &1})

    {:ok, updated_mails} =
      Repo.transaction(fn ->
        Enum.map(mails, fn mail ->
          case Map.get(assignments_by_mail_id, to_string(mail.id)) do
            nil -> mail
            assignment -> persist_replay_assignment(mail, assignment, rooms_by_name)
          end
        end)
      end)

    updated_mails
  end

  defp apply_replay_assignments(_blueprint, mails, _rooms), do: mails

  defp persist_replay_assignment(%Mail{} = mail, assignment, rooms_by_name) do
    room = Map.get(rooms_by_name, assignment["room"])

    attrs = %{
      "replay_room_id" => room && room.id,
      "replay_confidence" => assignment["confidence"],
      "replay_key" => assignment["key"],
      "replay_uncertain" => assignment["uncertain"] == true or is_nil(room)
    }

    mail |> Mail.changeset(attrs) |> Repo.update!()
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
      |> Repo.preload(:attachments)

    unclassified =
      Mail
      |> where([m], is_nil(m.space_id) and m.purpose == "inbox" and m.status == "unclassified")
      |> order_by([m], desc: m.occurred_at)
      |> Repo.all()
      |> Repo.preload(:attachments)

    %{routed: routed, unclassified: unclassified}
  end

  def list_unclassified(%User{}) do
    Mail
    |> where([m], is_nil(m.space_id) and m.purpose == "inbox" and m.status == "unclassified")
    |> order_by([m], desc: m.occurred_at)
    |> Repo.all()
    |> Repo.preload(:attachments)
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
      "inbox_id" => get_inbox!(space).id,
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
