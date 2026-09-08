defmodule M4w.World do
  @moduledoc """
  The world context.

  It owns goals, spaces, rooms, doors, keys, artifacts, entities, and passages.
  """

  import Ecto.Query, warn: false

  alias M4w.Repo
  alias Ecto.Changeset

  alias M4w.World.{
    Artifact,
    Door,
    DoorKey,
    Entity,
    Goal,
    Key,
    Passage,
    Room,
    Space,
    SpaceJsonSchema
  }

  def space_json_schema do
    SpaceJsonSchema.schema()
  end

  def space_json_schema_json do
    SpaceJsonSchema.json()
  end

  def list_goals do
    Repo.all(Goal)
  end

  def list_recent_goals(limit \\ 6) do
    Goal
    |> order_by([goal], desc: goal.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_goal!(id), do: Repo.get!(Goal, id)

  def create_goal(attrs \\ %{}) do
    %Goal{}
    |> Goal.changeset(attrs)
    |> Repo.insert()
  end

  def create_space_from_goal(attrs \\ %{}) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:goal, Goal.changeset(%Goal{}, attrs))
    |> Ecto.Multi.merge(fn %{goal: goal} -> default_space_multi(goal) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{space: space}} ->
        {:ok, preload_space_workflow(space)}

      {:error, operation, changeset, _changes} ->
        {:error, operation, changeset}
    end
  end

  @doc """
  Builds the fixed analysis/implementation/test/release template for an
  already-persisted goal. Used as a deterministic, free fallback when a
  design provider (see `M4w.Design`) fails or isn't configured.
  """
  def build_default_space(%Goal{} = goal) do
    goal
    |> default_space_multi()
    |> Repo.transaction()
    |> case do
      {:ok, %{space: space}} ->
        {:ok, preload_space_workflow(space)}

      {:error, operation, changeset, _changes} ->
        {:error, operation, changeset}
    end
  end

  @doc """
  Persists a generated space blueprint (see `M4w.World.space_json_schema/0`)
  for an already-persisted goal — rooms/keys/doors/entities/artifacts/
  passages referencing each other by their generation-time key/code/name
  rather than a database id.

  Returns `{:ok, space}` or `{:error, reason}` (a changeset or an
  `{:unknown_*, value}` tuple when the blueprint references a key that
  doesn't exist).
  """
  def create_space_from_blueprint(%Goal{} = goal, blueprint) when is_map(blueprint) do
    Repo.transaction(fn ->
      with {:ok, space} <- insert_blueprint_space(goal, blueprint),
           {:ok, rooms_by_key} <- insert_blueprint_rooms(space, blueprint),
           {:ok, keys_by_code} <- insert_blueprint_keys(space, blueprint),
           {:ok, doors_by_name} <- insert_blueprint_doors(space, blueprint, rooms_by_key),
           :ok <- insert_blueprint_door_keys(blueprint, doors_by_name, keys_by_code),
           {:ok, _entities} <- insert_blueprint_entities(space, blueprint, rooms_by_key),
           {:ok, artifacts_by_key} <- insert_blueprint_artifacts(space, blueprint, rooms_by_key),
           {:ok, _passages} <-
             insert_blueprint_passages(
               space,
               blueprint,
               rooms_by_key,
               artifacts_by_key,
               keys_by_code,
               doors_by_name
             ) do
        preload_space_workflow(space)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Creates a goal and designs its space via `M4w.Design`, falling back to
  `build_default_space/1` if the provider fails or returns an invalid
  blueprint. Always returns the `M4w.Design.Generation` audit record
  alongside the result so callers can show token usage/cost.
  """
  def design_space_from_goal(goal_attrs, opts \\ []) do
    with {:ok, goal} <- create_goal(goal_attrs) do
      request = design_request(goal)
      opts = Keyword.put(opts, :goal_id, goal.id)

      case M4w.Design.generate_blueprint(request, opts) do
        {:ok, blueprint, generation} ->
          case create_space_from_blueprint(goal, blueprint) do
            {:ok, space} ->
              {:ok, generation} = M4w.Design.attach_space(generation, space.id)
              {:ok, space, generation, :designed}

            {:error, _reason} ->
              fallback_space_from_goal(goal, generation)
          end

        {:error, _reason, generation} ->
          fallback_space_from_goal(goal, generation)
      end
    end
  end

  defp fallback_space_from_goal(goal, generation) do
    case build_default_space(goal) do
      {:ok, space} ->
        {:ok, generation} = M4w.Design.attach_space(generation, space.id)
        {:ok, space, generation, :fallback}

      {:error, operation, changeset} ->
        {:error, operation, changeset, generation}
    end
  end

  defp design_request(%Goal{} = goal) do
    %{
      system_prompt: design_system_prompt(),
      user_prompt: design_user_prompt(goal),
      tool_name: "emit_space_blueprint",
      tool_description: "Emit the designed space blueprint for this goal.",
      schema: space_json_schema() |> Map.drop(["$schema", "$id"])
    }
  end

  defp design_system_prompt do
    """
    Du är arkitekten i "MUD for Work": ett Goal skapar ett Space, ett \
    avgränsat arbetsrum med Rooms (episoder där en typ av arbete sker), \
    Doors (grindar mellan rum), Keys (villkor, behörigheter eller \
    kvalitetskrav som öppnar en dörr), Entities (AI-agenter, mänskliga \
    roller eller verktyg), Artifacts (spårbara arbetsresultat) och Passages \
    (spårbara övergångar mellan rum som bär en artifact och en used key).

    Designa en komplett, sammanhängande pipeline för målet du får:
    - Minst tre rum i en meningsfull ordning som passar målet (t.ex. \
    analys, byggande, verifiering, leverans — men anpassa rummen till vad \
    målet faktiskt kräver, inte en fast mall).
    - Dörrar som länkar rummen i rätt ordning; lås dörren och koppla minst \
    en key till den om ett villkor måste vara uppfyllt innan arbetet får \
    gå vidare.
    - Minst en artifact och en passage per dörr-passage, så att arbetet är \
    spårbart från rum till rum.
    - Namn och beskrivningar skrivs på svenska. `key`/`code`-fält är stabila, \
    url-säkra slugs (gemener, siffror, `_` eller `-`) och unika inom sin \
    lista.

    Svara enbart genom att anropa verktyget — inga fritextsvar.
    """
  end

  defp design_user_prompt(%Goal{title: title, description: description}) do
    """
    Goal: #{title}

    Kontext: #{description || "(ingen ytterligare kontext angiven)"}
    """
  end

  defp default_space_multi(goal) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:space, fn _changes ->
      Space.changeset(%Space{}, %{
        goal_id: goal.id,
        name: goal.title,
        description: goal.description
      })
    end)
    |> Ecto.Multi.run(:rooms, fn repo, %{space: space} ->
      {count, _rooms} = repo.insert_all(Room, default_room_entries(space))

      rooms_by_key =
        Room
        |> where([room], room.space_id == ^space.id)
        |> repo.all()
        |> Map.new(&{&1.key, &1})

      {:ok, %{count: count, by_key: rooms_by_key}}
    end)
    |> Ecto.Multi.run(:keys, fn repo, %{space: space} ->
      {count, _keys} = repo.insert_all(Key, default_key_entries(space))

      keys_by_code =
        Key
        |> where([key], key.space_id == ^space.id)
        |> repo.all()
        |> Map.new(&{&1.code, &1})

      {:ok, %{count: count, by_code: keys_by_code}}
    end)
    |> Ecto.Multi.run(:doors, fn repo, %{space: space, rooms: rooms, keys: keys} ->
      door_entries = default_door_entries(space, rooms.by_key)
      {count, _doors} = repo.insert_all(Door, door_entries)

      doors_by_name =
        Door
        |> where([door], door.space_id == ^space.id)
        |> repo.all()
        |> Map.new(&{&1.name, &1})

      door_key_entries = default_door_key_entries(doors_by_name, keys.by_code)
      {_count, _door_keys} = repo.insert_all(DoorKey, door_key_entries)

      {:ok, count}
    end)
  end

  defp insert_blueprint_space(goal, blueprint) do
    space_item = Map.get(blueprint, "space", %{}) || %{}

    create_space(%{
      goal_id: goal.id,
      name: space_item["name"] || goal.title,
      description: space_item["description"] || goal.description,
      metadata: space_item["metadata"] || %{}
    })
  end

  defp insert_blueprint_rooms(space, blueprint) do
    blueprint
    |> Map.get("rooms", [])
    |> insert_blueprint_items(&room_attrs(space, &1), &create_room/1, & &1.key)
  end

  defp room_attrs(space, item) do
    %{
      space_id: space.id,
      key: item["key"],
      name: item["name"],
      description: item["description"],
      kind: item["kind"] || "place",
      x: item["x"],
      y: item["y"],
      z: item["z"],
      metadata: item["metadata"] || %{}
    }
  end

  defp insert_blueprint_keys(space, blueprint) do
    blueprint
    |> Map.get("keys", [])
    |> insert_blueprint_items(&key_attrs(space, &1), &create_key/1, & &1.code)
  end

  defp key_attrs(space, item) do
    %{
      space_id: space.id,
      code: item["code"],
      name: item["name"],
      description: item["description"],
      kind: item["kind"] || "condition",
      status: item["status"] || "pending",
      criteria: item["criteria"] || %{},
      metadata: item["metadata"] || %{}
    }
  end

  defp insert_blueprint_items(items, attrs_fun, insert_fun, key_fun) do
    Enum.reduce_while(items, {:ok, %{}}, fn item, {:ok, acc} ->
      case item |> attrs_fun.() |> insert_fun.() do
        {:ok, record} -> {:cont, {:ok, Map.put(acc, key_fun.(record), record)}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp insert_blueprint_doors(space, blueprint, rooms_by_key) do
    blueprint
    |> Map.get("doors", [])
    |> Enum.reduce_while({:ok, %{}}, fn item, {:ok, acc} ->
      with {:ok, room_a} <- fetch_blueprint_room(rooms_by_key, item["room_a_key"]),
           {:ok, room_b} <- fetch_blueprint_room(rooms_by_key, item["room_b_key"]),
           {:ok, door} <- create_door(door_attrs(space, room_a, room_b, item)) do
        {:cont, {:ok, Map.put(acc, item["name"], door)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp door_attrs(space, room_a, room_b, item) do
    %{
      space_id: space.id,
      room_a_id: room_a.id,
      room_b_id: room_b.id,
      name: item["name"],
      description: item["description"],
      state: item["state"] || "open",
      locked: item["locked"] || false,
      metadata: item["metadata"] || %{}
    }
  end

  defp insert_blueprint_door_keys(blueprint, doors_by_name, keys_by_code) do
    blueprint
    |> Map.get("doors", [])
    |> Enum.reduce_while(:ok, fn item, :ok ->
      with {:ok, door} <- fetch_blueprint_door(doors_by_name, item["name"]),
           :ok <- insert_door_key_requirements(door, item["key_requirements"] || [], keys_by_code) do
        {:cont, :ok}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp insert_door_key_requirements(door, requirements, keys_by_code) do
    Enum.reduce_while(requirements, :ok, fn req, :ok ->
      with {:ok, key} <- fetch_blueprint_key(keys_by_code, req["key_code"]),
           {:ok, _door_key} <-
             require_key_for_door(door, key, %{
               requirement_kind: req["requirement_kind"] || "required",
               metadata: req["metadata"] || %{}
             }) do
        {:cont, :ok}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp insert_blueprint_entities(space, blueprint, rooms_by_key) do
    blueprint
    |> Map.get("entities", [])
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      with {:ok, room_id} <- fetch_blueprint_optional_room_id(rooms_by_key, item["room_key"]),
           {:ok, entity} <- create_entity(entity_attrs(space, room_id, item)) do
        {:cont, {:ok, [entity | acc]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> reverse_ok_list()
  end

  defp entity_attrs(space, room_id, item) do
    %{
      space_id: space.id,
      room_id: room_id,
      name: item["name"],
      description: item["description"],
      kind: item["kind"] || "thing",
      state: item["state"] || "idle",
      attributes: item["attributes"] || %{},
      metadata: item["metadata"] || %{}
    }
  end

  defp insert_blueprint_artifacts(space, blueprint, rooms_by_key) do
    blueprint
    |> Map.get("artifacts", [])
    |> Enum.reduce_while({:ok, %{}}, fn item, {:ok, acc} ->
      with {:ok, room_id} <- fetch_blueprint_optional_room_id(rooms_by_key, item["room_key"]),
           {:ok, artifact} <- create_artifact(artifact_attrs(space, room_id, item)) do
        {:cont, {:ok, Map.put(acc, item["key"], artifact)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp artifact_attrs(space, room_id, item) do
    %{
      space_id: space.id,
      room_id: room_id,
      key: item["key"],
      name: item["name"],
      description: item["description"],
      kind: item["kind"] || "work_product",
      status: item["status"] || "draft",
      content: item["content"] || %{},
      metadata: item["metadata"] || %{}
    }
  end

  defp insert_blueprint_passages(
         space,
         blueprint,
         rooms_by_key,
         artifacts_by_key,
         keys_by_code,
         doors_by_name
       ) do
    blueprint
    |> Map.get("passages", [])
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      with {:ok, from_room} <- fetch_blueprint_room(rooms_by_key, item["from_room_key"]),
           {:ok, to_room} <- fetch_blueprint_room(rooms_by_key, item["to_room_key"]),
           {:ok, artifact} <- fetch_blueprint_artifact(artifacts_by_key, item["artifact_key"]),
           {:ok, key} <- fetch_blueprint_key(keys_by_code, item["used_key_code"]),
           {:ok, door} <- fetch_blueprint_optional_door(doors_by_name, item["door_name"]),
           {:ok, passage} <-
             create_passage(passage_attrs(space, from_room, to_room, door, artifact, key, item)) do
        {:cont, {:ok, [passage | acc]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> reverse_ok_list()
  end

  defp passage_attrs(space, from_room, to_room, door, artifact, key, item) do
    %{
      space_id: space.id,
      from_room_id: from_room.id,
      to_room_id: to_room.id,
      door_id: door && door.id,
      artifact_id: artifact.id,
      used_key_id: key.id,
      direction: item["direction"],
      name: item["name"],
      description: item["description"],
      conditions: item["conditions"] || %{},
      metadata: item["metadata"] || %{}
    }
  end

  defp fetch_blueprint_room(rooms_by_key, key),
    do: fetch_blueprint_ref(rooms_by_key, key, :unknown_room_key)

  defp fetch_blueprint_key(keys_by_code, code),
    do: fetch_blueprint_ref(keys_by_code, code, :unknown_key_code)

  defp fetch_blueprint_artifact(artifacts_by_key, key),
    do: fetch_blueprint_ref(artifacts_by_key, key, :unknown_artifact_key)

  defp fetch_blueprint_door(doors_by_name, name),
    do: fetch_blueprint_ref(doors_by_name, name, :unknown_door_name)

  defp fetch_blueprint_ref(map, key, error_tag) do
    case Map.fetch(map, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {error_tag, key}}
    end
  end

  defp fetch_blueprint_optional_room_id(_rooms_by_key, nil), do: {:ok, nil}

  defp fetch_blueprint_optional_room_id(rooms_by_key, key) do
    with {:ok, room} <- fetch_blueprint_room(rooms_by_key, key), do: {:ok, room.id}
  end

  defp fetch_blueprint_optional_door(_doors_by_name, nil), do: {:ok, nil}

  defp fetch_blueprint_optional_door(doors_by_name, name),
    do: fetch_blueprint_door(doors_by_name, name)

  defp reverse_ok_list({:ok, list}), do: {:ok, Enum.reverse(list)}
  defp reverse_ok_list(error), do: error

  def update_goal(%Goal{} = goal, attrs) do
    goal
    |> Goal.changeset(attrs)
    |> Repo.update()
  end

  def delete_goal(%Goal{} = goal) do
    Repo.delete(goal)
  end

  def change_goal(%Goal{} = goal, attrs \\ %{}) do
    Goal.changeset(goal, attrs)
  end

  def list_spaces do
    Repo.all(Space)
  end

  def list_recent_spaces(limit \\ 12) do
    Space
    |> order_by([space], desc: space.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload(
      goal: [],
      rooms: room_order_query(),
      doors: door_order_query(),
      keys: key_order_query()
    )
  end

  def list_goal_spaces(%Goal{id: goal_id}), do: list_goal_spaces(goal_id)

  def list_goal_spaces(goal_id) do
    Space
    |> where([space], space.goal_id == ^goal_id)
    |> order_by([space], asc: space.name)
    |> Repo.all()
  end

  def get_space!(id), do: Repo.get!(Space, id)

  def get_space_with_workflow!(id) do
    Space
    |> Repo.get!(id)
    |> preload_space_workflow()
  end

  def create_space(attrs \\ %{}) do
    %Space{}
    |> Space.changeset(attrs)
    |> Repo.insert()
  end

  def update_space(%Space{} = space, attrs) do
    space
    |> Space.changeset(attrs)
    |> Repo.update()
  end

  def delete_space(%Space{} = space) do
    Repo.delete(space)
  end

  def change_space(%Space{} = space, attrs \\ %{}) do
    Space.changeset(space, attrs)
  end

  def list_rooms do
    Repo.all(Room)
  end

  def list_space_rooms(%Space{id: space_id}), do: list_space_rooms(space_id)

  def list_space_rooms(space_id) do
    Room
    |> where([room], room.space_id == ^space_id)
    |> order_by([room], asc: room.name)
    |> Repo.all()
  end

  def get_room!(id), do: Repo.get!(Room, id)

  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  defp preload_space_workflow(%Space{} = space) do
    Repo.preload(space, [
      :goal,
      rooms: room_order_query(),
      doors: door_order_query(),
      keys: key_order_query(),
      entities: entity_order_query(),
      artifacts: artifact_order_query(),
      passages: passage_order_query()
    ])
  end

  defp room_order_query do
    from(room in Room, order_by: [asc: room.x, asc: room.name])
  end

  defp entity_order_query do
    from(entity in Entity, order_by: [asc: entity.name])
  end

  defp artifact_order_query do
    from(artifact in Artifact, order_by: [asc: artifact.name])
  end

  defp passage_order_query do
    from(passage in Passage, order_by: [asc: passage.direction])
  end

  defp door_order_query do
    from(door in Door,
      order_by: [asc: door.inserted_at, asc: door.name],
      preload: [:room_a, :room_b, door_keys: ^door_key_order_query()]
    )
  end

  defp door_key_order_query do
    from(door_key in DoorKey,
      order_by: [asc: door_key.requirement_kind, asc: door_key.id],
      preload: [:key]
    )
  end

  defp key_order_query do
    from(key in Key, order_by: [asc: key.name])
  end

  defp default_room_entries(%Space{id: space_id}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    [
      %{
        key: "analysis",
        name: "Analys",
        description:
          "Forsta episoden dar malet bryts ner, risker hittas och arbetets form bestams.",
        kind: "analysis",
        x: 1,
        metadata: %{"progress" => 35, "status" => "in_progress"}
      },
      %{
        key: "implementation",
        name: "Implementation",
        description: "Har byggs losningen med ratt specialiserade modeller, roller och verktyg.",
        kind: "implementation",
        x: 2,
        metadata: %{"progress" => 12, "status" => "queued"}
      },
      %{
        key: "test",
        name: "Test",
        description:
          "Kvalitet, verifiering och acceptanskriterier samlas innan arbetet gar vidare.",
        kind: "test",
        x: 3,
        metadata: %{"progress" => 0, "status" => "locked"}
      },
      %{
        key: "release",
        name: "Release",
        description: "Sista episoden paketerar resultat, beslut och artefakter for leverans.",
        kind: "release",
        x: 4,
        metadata: %{"progress" => 0, "status" => "locked"}
      }
    ]
    |> Enum.map(fn room ->
      room
      |> Map.put(:space_id, space_id)
      |> Map.put(:inserted_at, now)
      |> Map.put(:updated_at, now)
    end)
  end

  defp default_key_entries(%Space{id: space_id}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    [
      %{
        code: "analysis_decision",
        name: "Analysbeslut",
        description: "Mal, risker och forsta plan ar tydliga nog for att oppna implementation.",
        kind: "condition",
        status: "pending",
        criteria: %{"evidence" => "En prioriterad plan och accepterade risker finns."},
        metadata: %{"unlocks" => "Implementation"}
      },
      %{
        code: "implementation_ready",
        name: "Byggbar losning",
        description: "Losningen ar byggd nog for strukturerad verifiering.",
        kind: "condition",
        status: "pending",
        criteria: %{"evidence" => "Kod, beslut och handoff ar samlade for test."},
        metadata: %{"unlocks" => "Test"}
      },
      %{
        code: "qa_clearance",
        name: "QA klartecken",
        description: "Verifieringen visar att resultatet kan paketeras for release.",
        kind: "approval",
        status: "pending",
        criteria: %{
          "evidence" => "Acceptanskriterier ar uppfyllda och kvarvarande risker ar synliga."
        },
        metadata: %{"unlocks" => "Release"}
      }
    ]
    |> Enum.map(fn key ->
      key
      |> Map.put(:space_id, space_id)
      |> Map.put(:inserted_at, now)
      |> Map.put(:updated_at, now)
    end)
  end

  defp default_door_entries(%Space{id: space_id}, rooms_by_key) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    default_door_specs()
    |> Enum.with_index()
    |> Enum.map(fn {spec, index} ->
      inserted_at = DateTime.add(now, index, :second)

      %{
        space_id: space_id,
        room_a_id: Map.fetch!(rooms_by_key, spec.room_a_key).id,
        room_b_id: Map.fetch!(rooms_by_key, spec.room_b_key).id,
        name: spec.name,
        description: spec.description,
        state: spec.state,
        locked: spec.locked,
        metadata: %{"direction" => spec.direction},
        inserted_at: inserted_at,
        updated_at: inserted_at
      }
    end)
  end

  defp default_door_key_entries(doors_by_name, keys_by_code) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    default_door_specs()
    |> Enum.flat_map(fn spec ->
      Enum.map(spec.key_codes, fn key_code ->
        %{
          door_id: Map.fetch!(doors_by_name, spec.name).id,
          key_id: Map.fetch!(keys_by_code, key_code).id,
          requirement_kind: "required",
          metadata: %{},
          inserted_at: now,
          updated_at: now
        }
      end)
    end)
  end

  defp default_door_specs do
    [
      %{
        name: "Grind till implementation",
        description: "Visar vad som maste vara sant innan arbetet gar fran analys till bygge.",
        room_a_key: "analysis",
        room_b_key: "implementation",
        state: "closed",
        locked: true,
        direction: "analysis_to_implementation",
        key_codes: ["analysis_decision"]
      },
      %{
        name: "Testgrind",
        description: "Samlar kraven som oppnar verifiering nar implementationen ar redo.",
        room_a_key: "implementation",
        room_b_key: "test",
        state: "closed",
        locked: true,
        direction: "implementation_to_test",
        key_codes: ["implementation_ready"]
      },
      %{
        name: "Releasegrind",
        description: "Tydliggor vilket klartecken som kravs innan resultatet far levereras.",
        room_a_key: "test",
        room_b_key: "release",
        state: "closed",
        locked: true,
        direction: "test_to_release",
        key_codes: ["qa_clearance"]
      }
    ]
  end

  def list_doors do
    Repo.all(Door)
  end

  def list_space_doors(%Space{id: space_id}), do: list_space_doors(space_id)

  def list_space_doors(space_id) do
    Door
    |> where([door], door.space_id == ^space_id)
    |> order_by([door], asc: door.name)
    |> Repo.all()
  end

  def get_door!(id), do: Repo.get!(Door, id)

  def create_door(attrs \\ %{}) do
    %Door{}
    |> Door.changeset(attrs)
    |> Repo.insert()
  end

  def update_door(%Door{} = door, attrs) do
    door
    |> Door.changeset(attrs)
    |> Repo.update()
  end

  def delete_door(%Door{} = door) do
    Repo.delete(door)
  end

  def change_door(%Door{} = door, attrs \\ %{}) do
    Door.changeset(door, attrs)
  end

  def list_keys do
    Repo.all(Key)
  end

  def list_space_keys(%Space{id: space_id}), do: list_space_keys(space_id)

  def list_space_keys(space_id) do
    Key
    |> where([key], key.space_id == ^space_id)
    |> order_by([key], asc: key.name)
    |> Repo.all()
  end

  def list_required_keys_for_door(%Door{id: door_id}), do: list_required_keys_for_door(door_id)

  def list_required_keys_for_door(door_id) do
    Key
    |> join(:inner, [key], door_key in DoorKey, on: door_key.key_id == key.id)
    |> where([key, door_key], door_key.door_id == ^door_id)
    |> order_by([key], asc: key.name)
    |> Repo.all()
  end

  def get_key!(id), do: Repo.get!(Key, id)

  def create_key(attrs \\ %{}) do
    %Key{}
    |> Key.changeset(attrs)
    |> Repo.insert()
  end

  def update_key(%Key{} = key, attrs) do
    key
    |> Key.changeset(attrs)
    |> Repo.update()
  end

  def delete_key(%Key{} = key) do
    Repo.delete(key)
  end

  def change_key(%Key{} = key, attrs \\ %{}) do
    Key.changeset(key, attrs)
  end

  def list_artifacts do
    Repo.all(Artifact)
  end

  def list_space_artifacts(%Space{id: space_id}), do: list_space_artifacts(space_id)

  def list_space_artifacts(space_id) do
    Artifact
    |> where([artifact], artifact.space_id == ^space_id)
    |> order_by([artifact], asc: artifact.name)
    |> Repo.all()
  end

  def list_room_artifacts(%Room{id: room_id}), do: list_room_artifacts(room_id)

  def list_room_artifacts(room_id) do
    Artifact
    |> where([artifact], artifact.room_id == ^room_id)
    |> order_by([artifact], asc: artifact.name)
    |> Repo.all()
  end

  def get_artifact!(id), do: Repo.get!(Artifact, id)

  def create_artifact(attrs \\ %{}) do
    %Artifact{}
    |> Artifact.changeset(attrs)
    |> validate_artifact_room_space()
    |> Repo.insert()
  end

  def update_artifact(%Artifact{} = artifact, attrs) do
    artifact
    |> Artifact.changeset(attrs)
    |> validate_artifact_room_space()
    |> Repo.update()
  end

  def delete_artifact(%Artifact{} = artifact) do
    Repo.delete(artifact)
  end

  def change_artifact(%Artifact{} = artifact, attrs \\ %{}) do
    Artifact.changeset(artifact, attrs)
  end

  defp validate_artifact_room_space(changeset) do
    space_id = Changeset.get_field(changeset, :space_id)
    room_id = Changeset.get_field(changeset, :room_id)

    with true <- changeset.valid?,
         true <- is_integer(space_id),
         true <- is_integer(room_id),
         %Room{} = room <- Repo.get(Room, room_id),
         false <- room.space_id == space_id do
      Changeset.add_error(changeset, :room_id, "must belong to the same space as the artifact")
    else
      _ -> changeset
    end
  end

  def list_door_key_requirements(%Door{id: door_id}), do: list_door_key_requirements(door_id)

  def list_door_key_requirements(door_id) do
    DoorKey
    |> where([door_key], door_key.door_id == ^door_id)
    |> preload(:key)
    |> Repo.all()
  end

  def get_door_key!(id), do: Repo.get!(DoorKey, id)

  def require_key_for_door(%Door{} = door, %Key{} = key, attrs \\ %{}) do
    attrs
    |> normalize_door_key_attrs()
    |> Map.merge(%{door_id: door.id, key_id: key.id})
    |> create_door_key()
  end

  def create_door_key(attrs \\ %{}) do
    %DoorKey{}
    |> DoorKey.changeset(normalize_door_key_attrs(attrs))
    |> validate_door_key_space()
    |> Repo.insert()
  end

  def update_door_key(%DoorKey{} = door_key, attrs) do
    door_key
    |> DoorKey.changeset(normalize_door_key_attrs(attrs))
    |> validate_door_key_space()
    |> Repo.update()
  end

  def delete_door_key(%DoorKey{} = door_key) do
    Repo.delete(door_key)
  end

  def change_door_key(%DoorKey{} = door_key, attrs \\ %{}) do
    DoorKey.changeset(door_key, normalize_door_key_attrs(attrs))
  end

  defp normalize_door_key_attrs(attrs) do
    attrs
    |> Map.new()
    |> Enum.reduce(%{}, fn
      {"door_id", value}, normalized -> Map.put(normalized, :door_id, value)
      {"key_id", value}, normalized -> Map.put(normalized, :key_id, value)
      {"requirement_kind", value}, normalized -> Map.put(normalized, :requirement_kind, value)
      {"metadata", value}, normalized -> Map.put(normalized, :metadata, value)
      {key, value}, normalized -> Map.put(normalized, key, value)
    end)
  end

  defp validate_door_key_space(changeset) do
    door_id = Ecto.Changeset.get_field(changeset, :door_id)
    key_id = Ecto.Changeset.get_field(changeset, :key_id)

    with true <- changeset.valid?,
         true <- is_integer(door_id),
         true <- is_integer(key_id),
         %Door{} = door <- Repo.get(Door, door_id),
         %Key{} = key <- Repo.get(Key, key_id),
         false <- door.space_id == key.space_id do
      Changeset.add_error(changeset, :key_id, "must belong to the same space as the door")
    else
      _ -> changeset
    end
  end

  def list_entities do
    Repo.all(Entity)
  end

  def list_space_entities(%Space{id: space_id}), do: list_space_entities(space_id)

  def list_space_entities(space_id) do
    Entity
    |> where([entity], entity.space_id == ^space_id)
    |> order_by([entity], asc: entity.name)
    |> Repo.all()
  end

  def list_room_entities(%Room{id: room_id}), do: list_room_entities(room_id)

  def list_room_entities(room_id) do
    Entity
    |> where([entity], entity.room_id == ^room_id)
    |> order_by([entity], asc: entity.name)
    |> Repo.all()
  end

  def get_entity!(id), do: Repo.get!(Entity, id)

  def create_entity(attrs \\ %{}) do
    %Entity{}
    |> Entity.changeset(attrs)
    |> Repo.insert()
  end

  def update_entity(%Entity{} = entity, attrs) do
    entity
    |> Entity.changeset(attrs)
    |> Repo.update()
  end

  def delete_entity(%Entity{} = entity) do
    Repo.delete(entity)
  end

  def change_entity(%Entity{} = entity, attrs \\ %{}) do
    Entity.changeset(entity, attrs)
  end

  def list_passages do
    Repo.all(Passage)
  end

  def list_space_passages(%Space{id: space_id}), do: list_space_passages(space_id)

  def list_space_passages(space_id) do
    Passage
    |> where([passage], passage.space_id == ^space_id)
    |> order_by([passage], asc: passage.direction)
    |> Repo.all()
  end

  def list_room_passages(%Room{id: room_id}), do: list_room_passages(room_id)

  def list_room_passages(room_id) do
    Passage
    |> where([passage], passage.from_room_id == ^room_id)
    |> order_by([passage], asc: passage.direction)
    |> Repo.all()
  end

  def get_passage!(id), do: Repo.get!(Passage, id)

  def create_passage(attrs \\ %{}) do
    %Passage{}
    |> Passage.changeset(attrs)
    |> validate_passage_space()
    |> validate_passage_door()
    |> validate_passage_used_key()
    |> Repo.insert()
  end

  def update_passage(%Passage{} = passage, attrs) do
    passage
    |> Passage.changeset(attrs)
    |> validate_passage_space()
    |> validate_passage_door()
    |> validate_passage_used_key()
    |> Repo.update()
  end

  def delete_passage(%Passage{} = passage) do
    Repo.delete(passage)
  end

  def change_passage(%Passage{} = passage, attrs \\ %{}) do
    Passage.changeset(passage, attrs)
  end

  defp validate_passage_space(changeset) do
    changeset
    |> validate_passage_reference_space(:from_room_id, Room)
    |> validate_passage_reference_space(:to_room_id, Room)
    |> validate_passage_reference_space(:door_id, Door, optional: true)
    |> validate_passage_reference_space(:artifact_id, Artifact)
    |> validate_passage_reference_space(:used_key_id, Key)
  end

  defp validate_passage_reference_space(changeset, field, schema, opts \\ []) do
    space_id = Changeset.get_field(changeset, :space_id)
    id = Changeset.get_field(changeset, field)

    cond do
      Keyword.get(opts, :optional, false) && is_nil(id) ->
        changeset

      not changeset.valid? || not is_integer(space_id) || not is_integer(id) ->
        changeset

      true ->
        case Repo.get(schema, id) do
          %{space_id: ^space_id} ->
            changeset

          %{space_id: _} ->
            Changeset.add_error(changeset, field, "must belong to the same space as the passage")

          nil ->
            changeset
        end
    end
  end

  defp validate_passage_door(changeset) do
    door_id = Changeset.get_field(changeset, :door_id)
    from_room_id = Changeset.get_field(changeset, :from_room_id)
    to_room_id = Changeset.get_field(changeset, :to_room_id)

    with true <- changeset.valid?,
         true <- is_integer(door_id),
         true <- is_integer(from_room_id),
         true <- is_integer(to_room_id),
         %Door{} = door <- Repo.get(Door, door_id),
         false <- door_connects_rooms?(door, from_room_id, to_room_id) do
      Changeset.add_error(changeset, :door_id, "must connect the passage rooms")
    else
      _ -> changeset
    end
  end

  defp validate_passage_used_key(changeset) do
    door_id = Changeset.get_field(changeset, :door_id)
    used_key_id = Changeset.get_field(changeset, :used_key_id)

    with true <- changeset.valid?,
         true <- is_integer(door_id),
         true <- is_integer(used_key_id),
         false <- door_uses_key?(door_id, used_key_id) do
      Changeset.add_error(changeset, :used_key_id, "must be required by the passage door")
    else
      _ -> changeset
    end
  end

  defp door_connects_rooms?(%Door{} = door, from_room_id, to_room_id) do
    Enum.sort([door.room_a_id, door.room_b_id]) == Enum.sort([from_room_id, to_room_id])
  end

  defp door_uses_key?(door_id, key_id) do
    DoorKey
    |> where([door_key], door_key.door_id == ^door_id and door_key.key_id == ^key_id)
    |> Repo.exists?()
  end
end
