defmodule M4wWeb.BuilderLive do
  use M4wWeb, :live_view

  alias M4w.World
  alias M4w.World.{Door, DoorKey, Goal, Key, Room, Space}

  @impl true
  def mount(_params, _session, socket) do
    spaces = World.list_recent_spaces()
    selected_space = List.first(spaces)
    selected_room = first_room(selected_space)

    socket =
      socket
      |> assign(:goal_form, to_form(World.change_goal(%Goal{})))
      |> assign(:selected_space, selected_space)
      |> assign(:selected_room, selected_room)
      |> assign_room_instruction_form(selected_room)
      |> stream(:spaces, spaces)
      |> stream(:selected_rooms, rooms_for(selected_space))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_goal", %{"goal" => goal_params}, socket) do
    changeset =
      %Goal{}
      |> World.change_goal(clean_goal_params(goal_params))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :goal_form, to_form(changeset))}
  end

  def handle_event("create_space", %{"goal" => goal_params}, socket) do
    goal_params = clean_goal_params(goal_params)

    case World.create_space_from_goal(goal_params) do
      {:ok, space} ->
        spaces = World.list_recent_spaces()

        socket =
          socket
          |> put_flash(:info, "Ny serie skapad från ditt goal.")
          |> assign(:goal_form, to_form(World.change_goal(%Goal{})))
          |> select_space(space)
          |> stream(:spaces, spaces, reset: true)

        {:noreply, socket}

      {:error, :goal, changeset} ->
        {:noreply, assign(socket, :goal_form, to_form(%{changeset | action: :insert}))}

      {:error, _operation, _changeset} ->
        {:noreply, put_flash(socket, :error, "Kunde inte skapa serien just nu.")}
    end
  end

  def handle_event("select_space", %{"id" => id}, socket) do
    {:noreply, select_space(socket, World.get_space_with_workflow!(id))}
  end

  def handle_event("select_room", %{"id" => id}, socket) do
    selected_room =
      socket.assigns.selected_space
      |> rooms_for()
      |> Enum.find(&("#{&1.id}" == id))

    socket =
      socket
      |> assign(:selected_room, selected_room)
      |> assign_room_instruction_form(selected_room)
      |> stream(:selected_rooms, rooms_for(socket.assigns.selected_space), reset: true)

    {:noreply, socket}
  end

  def handle_event("save_room_instruction", %{"room_instruction" => params}, socket) do
    instruction = params |> Map.get("instruction", "") |> String.trim()
    room = socket.assigns.selected_room
    metadata = room.metadata || %{}

    case World.update_room(room, %{metadata: Map.put(metadata, "instruction", instruction)}) do
      {:ok, updated_room} ->
        selected_space = World.get_space_with_workflow!(socket.assigns.selected_space.id)
        spaces = World.list_recent_spaces()

        socket =
          socket
          |> put_flash(:info, "Instruktionen sparades för episoden.")
          |> assign(:selected_space, selected_space)
          |> assign(:selected_room, updated_room)
          |> assign_room_instruction_form(updated_room)
          |> stream(:selected_rooms, selected_space.rooms, reset: true)
          |> stream(:spaces, spaces, reset: true)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Kunde inte spara instruktionen.")}
    end
  end

  defp select_space(socket, %Space{} = space) do
    selected_room = first_room(space)

    socket
    |> assign(:selected_space, space)
    |> assign(:selected_room, selected_room)
    |> assign_room_instruction_form(selected_room)
    |> stream(:selected_rooms, rooms_for(space), reset: true)
  end

  defp select_space(socket, nil) do
    socket
    |> assign(:selected_space, nil)
    |> assign(:selected_room, nil)
    |> assign_room_instruction_form(nil)
    |> stream(:selected_rooms, [], reset: true)
  end

  defp clean_goal_params(params) do
    params
    |> Map.take(["title", "description"])
    |> Map.update("title", "", &String.trim/1)
    |> Map.update("description", "", &String.trim/1)
  end

  defp assign_room_instruction_form(socket, nil) do
    assign(socket, :room_instruction_form, to_form(%{"instruction" => ""}, as: :room_instruction))
  end

  defp assign_room_instruction_form(socket, %Room{} = room) do
    instruction = (room.metadata || %{}) |> Map.get("instruction", "")

    assign(
      socket,
      :room_instruction_form,
      to_form(%{"instruction" => instruction}, as: :room_instruction)
    )
  end

  defp first_room(nil), do: nil
  defp first_room(%Space{} = space), do: List.first(rooms_for(space))

  defp rooms_for(nil), do: []
  defp rooms_for(%Space{rooms: rooms}) when is_list(rooms), do: rooms
  defp rooms_for(_space), do: []

  defp doors_for(%Space{doors: %Ecto.Association.NotLoaded{}}), do: []
  defp doors_for(%Space{doors: doors}) when is_list(doors), do: doors
  defp doors_for(_space), do: []

  defp doors_for_room(nil, _room), do: []
  defp doors_for_room(_space, nil), do: []

  defp doors_for_room(%Space{} = space, %Room{id: room_id}) do
    space
    |> doors_for()
    |> Enum.filter(fn door -> door.room_a_id == room_id || door.room_b_id == room_id end)
  end

  defp door_count_label(count) do
    case count do
      1 -> "1 dörr"
      count -> "#{count} dörrar"
    end
  end

  defp other_room_name(%Door{room_a_id: room_id, room_b: room}, %Room{id: room_id}) do
    room_name(room)
  end

  defp other_room_name(%Door{room_b_id: room_id, room_a: room}, %Room{id: room_id}) do
    room_name(room)
  end

  defp other_room_name(_door, _room), do: "Annat room"

  defp room_name(%Room{name: name}) when is_binary(name), do: name
  defp room_name(_room), do: "Annat room"

  defp door_key_requirements(%Door{door_keys: door_keys}) when is_list(door_keys), do: door_keys
  defp door_key_requirements(_door), do: []

  defp key_for(%DoorKey{key: %Key{} = key}), do: key
  defp key_for(_door_key), do: nil

  defp key_name(%Key{name: name}) when is_binary(name), do: name
  defp key_name(_key), do: "Okänd nyckel"

  defp key_description(%Key{description: description}) when is_binary(description),
    do: description

  defp key_description(_key), do: nil

  defp key_status_label(%Key{status: "satisfied"}), do: "Uppfylld"
  defp key_status_label(%Key{status: "active"}), do: "Aktiv"
  defp key_status_label(%Key{status: "pending"}), do: "Väntar"

  defp key_status_label(%Key{status: status}) when is_binary(status),
    do: String.capitalize(status)

  defp key_status_label(_key), do: "Väntar"

  defp key_status_classes(%Key{status: "satisfied"}),
    do: "border-emerald-400/30 bg-emerald-400/10 text-emerald-200"

  defp key_status_classes(%Key{status: "active"}),
    do: "border-sky-400/30 bg-sky-400/10 text-sky-200"

  defp key_status_classes(_key), do: "border-amber-300/30 bg-amber-300/10 text-amber-100"

  defp door_lock_label(%Door{locked: true}), do: "Låst"
  defp door_lock_label(%Door{locked: false}), do: "Öppen"
  defp door_lock_label(_door), do: "Okänd"

  defp door_lock_icon(%Door{locked: true}), do: "hero-lock-closed"
  defp door_lock_icon(_door), do: "hero-lock-open"

  defp door_lock_classes(%Door{locked: true}), do: "border-red-400/30 bg-red-500/10 text-red-200"
  defp door_lock_classes(_door), do: "border-emerald-400/30 bg-emerald-400/10 text-emerald-200"

  defp door_state_label(%Door{state: "closed"}), do: "Stängd"
  defp door_state_label(%Door{state: "open"}), do: "Öppen"
  defp door_state_label(%Door{state: "blocked"}), do: "Blockerad"
  defp door_state_label(%Door{state: "complete"}), do: "Klar"
  defp door_state_label(%Door{state: state}) when is_binary(state), do: String.capitalize(state)
  defp door_state_label(_door), do: "Okänd"

  defp progress_for(%Space{} = space) do
    rooms = rooms_for(space)

    if rooms == [] do
      0
    else
      rooms
      |> Enum.map(&progress_for/1)
      |> Enum.sum()
      |> div(length(rooms))
    end
  end

  defp progress_for(%Room{} = room) do
    (room.metadata || %{})
    |> Map.get("progress", 0)
    |> normalize_progress()
  end

  defp normalize_progress(progress) when is_integer(progress), do: progress |> max(0) |> min(100)

  defp normalize_progress(progress) when is_binary(progress) do
    case Integer.parse(progress) do
      {value, _rest} -> normalize_progress(value)
      :error -> 0
    end
  end

  defp normalize_progress(_progress), do: 0

  defp status_for(%Room{} = room) do
    (room.metadata || %{})
    |> Map.get("status", "queued")
    |> status_label()
  end

  defp status_for(%Space{} = space) do
    progress = progress_for(space)

    cond do
      progress >= 100 -> "Klar"
      progress > 0 -> "Pågår"
      true -> "Köad"
    end
  end

  defp status_label("done"), do: "Klar"
  defp status_label("in_progress"), do: "Pågår"
  defp status_label("locked"), do: "Låst"
  defp status_label("queued"), do: "Köad"
  defp status_label(status) when is_binary(status), do: String.capitalize(status)
  defp status_label(_status), do: "Köad"

  defp status_classes("Klar"), do: "bg-emerald-400 text-zinc-950"
  defp status_classes("Pågår"), do: "bg-red-500 text-white"
  defp status_classes("Låst"), do: "bg-zinc-700 text-zinc-200"
  defp status_classes(_status), do: "bg-amber-300 text-zinc-950"

  defp series_pitch(nil), do: "Skapa ett goal för att starta första serien."
  defp series_pitch(%Space{description: nil}), do: "En arbetsserie byggd från ditt goal."
  defp series_pitch(%Space{description: ""}), do: "En arbetsserie byggd från ditt goal."
  defp series_pitch(%Space{description: description}), do: description

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="builder-shell" class="min-h-[calc(100vh-4rem)] bg-zinc-950 text-white">
        <section class="relative overflow-hidden border-b border-white/10">
          <div class="absolute inset-0 bg-[linear-gradient(90deg,rgba(9,9,11,1)_0%,rgba(9,9,11,0.9)_52%,rgba(39,39,42,0.72)_100%)]" />
          <div class="relative mx-auto grid min-h-[32rem] max-w-7xl gap-8 px-4 py-10 sm:px-6 lg:grid-cols-[minmax(0,1fr)_25rem] lg:px-8">
            <div class="flex flex-col justify-end pb-4">
              <div class="mb-8 inline-flex w-fit items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-zinc-200">
                <.icon name="hero-tv" class="size-4 text-red-400" /> MUD for Work
              </div>

              <div :if={@selected_space} id="selected-series-hero">
                <div class="mb-3 flex flex-wrap items-center gap-2">
                  <span class={[
                    "rounded px-2 py-1 text-xs font-bold uppercase tracking-[0.12em]",
                    status_classes(status_for(@selected_space))
                  ]}>
                    {status_for(@selected_space)}
                  </span>
                  <span class="text-sm text-zinc-300">
                    {length(rooms_for(@selected_space))} episoder
                  </span>
                </div>
                <h1 class="max-w-4xl text-4xl font-black tracking-normal text-white sm:text-6xl">
                  {@selected_space.name}
                </h1>
                <p class="mt-5 max-w-2xl text-base leading-7 text-zinc-200 sm:text-lg">
                  {series_pitch(@selected_space)}
                </p>
                <div class="mt-7 max-w-xl">
                  <div class="flex items-center justify-between text-xs font-semibold uppercase tracking-[0.14em] text-zinc-300">
                    <span>Total progress</span>
                    <span>{progress_for(@selected_space)}%</span>
                  </div>
                  <div class="mt-2 h-2 overflow-hidden rounded-full bg-white/15">
                    <div
                      class="h-full rounded-full bg-red-500 transition-all duration-500"
                      style={"width: #{progress_for(@selected_space)}%"}
                    />
                  </div>
                </div>
              </div>

              <div :if={!@selected_space} id="empty-series-hero">
                <h1 class="max-w-4xl text-4xl font-black tracking-normal text-white sm:text-6xl">
                  Skapa första arbetsserien.
                </h1>
                <p class="mt-5 max-w-2xl text-base leading-7 text-zinc-200 sm:text-lg">
                  Skriv ett goal så skapas ett Space med episoder för analys, implementation, test och release.
                </p>
              </div>
            </div>

            <div class="flex items-end">
              <.form
                for={@goal_form}
                id="goal-builder-form"
                phx-change="validate_goal"
                phx-submit="create_space"
                class="w-full rounded-lg border border-white/15 bg-zinc-900/90 p-4 shadow-2xl backdrop-blur"
              >
                <div class="mb-4 flex items-center gap-2">
                  <.icon name="hero-sparkles" class="size-5 text-red-400" />
                  <h2 class="text-sm font-semibold uppercase tracking-[0.16em] text-zinc-200">
                    Ny serie från goal
                  </h2>
                </div>
                <.input
                  field={@goal_form[:title]}
                  id="goal-title-input"
                  type="text"
                  label="Goal"
                  placeholder="Ex: Lansera en kundportal"
                  autocomplete="off"
                  required
                  class="min-h-12 w-full rounded-md border border-white/15 bg-zinc-950 px-3 py-2 text-base text-white outline-none transition duration-200 placeholder:text-zinc-500 focus:border-red-400 focus:ring-4 focus:ring-red-500/20"
                />
                <.input
                  field={@goal_form[:description]}
                  id="goal-description-input"
                  type="textarea"
                  label="Context"
                  placeholder="Beskriv mål, målgrupp och viktigaste resultat."
                  rows="4"
                  class="min-h-28 w-full resize-y rounded-md border border-white/15 bg-zinc-950 px-3 py-2 text-sm leading-6 text-white outline-none transition duration-200 placeholder:text-zinc-500 focus:border-red-400 focus:ring-4 focus:ring-red-500/20"
                />
                <button
                  id="generate-goal-button"
                  type="submit"
                  class="mt-2 inline-flex min-h-10 w-full items-center justify-center gap-2 rounded-md bg-red-600 px-4 py-2 text-sm font-bold text-white shadow-lg shadow-red-950/30 transition duration-200 hover:bg-red-500 focus:outline-none focus:ring-4 focus:ring-red-500/25 phx-submit-loading:opacity-70"
                >
                  <.icon name="hero-play-solid" class="size-4" /> Skapa serie
                </button>
              </.form>
            </div>
          </div>
        </section>

        <section class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
          <div class="mb-4 flex items-center justify-between gap-3">
            <h2 class="text-xl font-bold tracking-normal text-white">Dina serier</h2>
            <span class="text-sm text-zinc-400">Spaces</span>
          </div>

          <div id="spaces" phx-update="stream" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <div
              id="spaces-empty"
              class="hidden min-h-44 rounded-lg border border-dashed border-white/15 bg-white/[0.04] p-5 text-sm leading-6 text-zinc-400 only:block"
            >
              Inga serier ännu. Skapa ett goal ovan.
            </div>
            <button
              :for={{id, space} <- @streams.spaces}
              id={id}
              type="button"
              phx-click="select_space"
              phx-value-id={space.id}
              class={[
                "group min-h-48 rounded-lg border p-4 text-left transition duration-200 hover:-translate-y-1 hover:border-red-500/70 hover:bg-white/[0.08]",
                @selected_space && @selected_space.id == space.id &&
                  "border-red-500 bg-white/[0.08] shadow-lg shadow-red-950/20",
                (!@selected_space || @selected_space.id != space.id) &&
                  "border-white/10 bg-white/[0.045]"
              ]}
            >
              <div class="flex items-start justify-between gap-3">
                <span class={[
                  "rounded px-2 py-1 text-xs font-bold uppercase tracking-[0.12em]",
                  status_classes(status_for(space))
                ]}>
                  {status_for(space)}
                </span>
                <.icon
                  name="hero-play-circle"
                  class="size-6 text-white/45 transition group-hover:text-red-400"
                />
              </div>
              <h3 class="mt-8 line-clamp-2 text-lg font-bold leading-6 text-white">{space.name}</h3>
              <p class="mt-2 line-clamp-2 text-sm leading-6 text-zinc-400">{series_pitch(space)}</p>
              <div class="mt-5">
                <div class="flex items-center justify-between text-xs text-zinc-400">
                  <span>{length(rooms_for(space))} episoder</span>
                  <span>{progress_for(space)}%</span>
                </div>
                <div class="mt-2 h-1.5 overflow-hidden rounded-full bg-white/10">
                  <div
                    class="h-full rounded-full bg-red-500 transition-all duration-500"
                    style={"width: #{progress_for(space)}%"}
                  />
                </div>
              </div>
            </button>
          </div>
        </section>

        <section class="mx-auto grid max-w-7xl gap-6 px-4 pb-10 sm:px-6 lg:grid-cols-[minmax(0,1fr)_24rem] lg:px-8">
          <div>
            <div class="mb-4 flex items-center justify-between gap-3">
              <h2 class="text-xl font-bold tracking-normal text-white">Episoder</h2>
              <span class="text-sm text-zinc-400">Rooms</span>
            </div>

            <div id="selected-rooms" phx-update="stream" class="grid gap-4 md:grid-cols-2">
              <div
                id="selected-rooms-empty"
                class="hidden rounded-lg border border-dashed border-white/15 bg-white/[0.04] p-5 text-sm leading-6 text-zinc-400 only:block"
              >
                Välj eller skapa en serie för att se episoder.
              </div>
              <button
                :for={{id, room} <- @streams.selected_rooms}
                id={id}
                type="button"
                phx-click="select_room"
                phx-value-id={room.id}
                class={[
                  "rounded-lg border p-4 text-left transition duration-200 hover:border-red-500/70 hover:bg-white/[0.08]",
                  @selected_room && @selected_room.id == room.id &&
                    "border-red-500 bg-white/[0.08]",
                  (!@selected_room || @selected_room.id != room.id) &&
                    "border-white/10 bg-white/[0.045]"
                ]}
              >
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p class="text-xs font-semibold uppercase tracking-[0.16em] text-zinc-500">
                      Episode {room.x || 0}
                    </p>
                    <h3 class="mt-1 text-lg font-bold text-white">{room.name}</h3>
                  </div>
                  <span class={[
                    "rounded px-2 py-1 text-xs font-bold uppercase tracking-[0.12em]",
                    status_classes(status_for(room))
                  ]}>
                    {status_for(room)}
                  </span>
                </div>
                <p class="mt-3 line-clamp-2 text-sm leading-6 text-zinc-400">{room.description}</p>
                <div class="mt-5">
                  <div class="flex items-center justify-between text-xs text-zinc-400">
                    <span>Progress</span>
                    <span>{progress_for(room)}%</span>
                  </div>
                  <div class="mt-2 h-1.5 overflow-hidden rounded-full bg-white/10">
                    <div
                      class="h-full rounded-full bg-red-500 transition-all duration-500"
                      style={"width: #{progress_for(room)}%"}
                    />
                  </div>
                </div>
                <div class="mt-4 flex items-center gap-2 text-xs font-medium text-zinc-400">
                  <.icon name="hero-key" class="size-4 text-red-300" />
                  <span>{door_count_label(length(doors_for_room(@selected_space, room)))}</span>
                </div>
              </button>
            </div>
          </div>

          <aside class="rounded-lg border border-white/10 bg-white/[0.045] p-5">
            <div :if={@selected_room} id="room-detail">
              <div class="flex items-start justify-between gap-3">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-[0.16em] text-red-300">
                    Room prompt
                  </p>
                  <h2 class="mt-2 text-2xl font-bold tracking-normal text-white">
                    {@selected_room.name}
                  </h2>
                </div>
                <span class={[
                  "rounded px-2 py-1 text-xs font-bold uppercase tracking-[0.12em]",
                  status_classes(status_for(@selected_room))
                ]}>
                  {status_for(@selected_room)}
                </span>
              </div>

              <p class="mt-4 text-sm leading-6 text-zinc-300">{@selected_room.description}</p>

              <div class="mt-5">
                <div class="flex items-center justify-between text-xs font-semibold uppercase tracking-[0.14em] text-zinc-400">
                  <span>Episode progress</span>
                  <span>{progress_for(@selected_room)}%</span>
                </div>
                <div class="mt-2 h-2 overflow-hidden rounded-full bg-white/10">
                  <div
                    class="h-full rounded-full bg-red-500 transition-all duration-500"
                    style={"width: #{progress_for(@selected_room)}%"}
                  />
                </div>
              </div>

              <div id="room-doors" class="mt-6 rounded-lg border border-white/10 bg-zinc-950/60 p-4">
                <div class="flex items-center justify-between gap-3">
                  <div class="flex items-center gap-2">
                    <.icon name="hero-key" class="size-5 text-red-300" />
                    <h3 class="text-sm font-bold uppercase tracking-[0.14em] text-zinc-200">
                      Dörrar och nycklar
                    </h3>
                  </div>
                  <span class="text-xs font-semibold text-zinc-400">
                    {door_count_label(length(doors_for_room(@selected_space, @selected_room)))}
                  </span>
                </div>

                <div
                  :if={doors_for_room(@selected_space, @selected_room) == []}
                  id="room-doors-empty"
                  class="mt-4 rounded-md border border-dashed border-white/10 bg-white/[0.03] p-3 text-sm leading-6 text-zinc-400"
                >
                  Inga dörrar är kopplade till det här roomet ännu.
                </div>

                <div
                  :for={door <- doors_for_room(@selected_space, @selected_room)}
                  id={"room-door-#{door.id}"}
                  class="mt-4 rounded-md border border-white/10 bg-white/[0.035] p-3"
                >
                  <div class="flex items-start justify-between gap-3">
                    <div>
                      <div class="flex items-center gap-2">
                        <h4 class="text-sm font-bold text-white">{door.name}</h4>
                        <span class={[
                          "inline-flex items-center gap-1 rounded border px-2 py-0.5 text-xs font-semibold",
                          door_lock_classes(door)
                        ]}>
                          <.icon name={door_lock_icon(door)} class="size-3.5" />
                          {door_lock_label(door)}
                        </span>
                      </div>
                      <p class="mt-1 flex items-center gap-1 text-xs text-zinc-400">
                        <span>{@selected_room.name}</span>
                        <.icon name="hero-arrow-right" class="size-3.5 text-zinc-500" />
                        <span>{other_room_name(door, @selected_room)}</span>
                      </p>
                    </div>
                    <span class="rounded bg-white/10 px-2 py-1 text-xs font-semibold text-zinc-300">
                      {door_state_label(door)}
                    </span>
                  </div>

                  <p :if={door.description} class="mt-3 text-sm leading-6 text-zinc-400">
                    {door.description}
                  </p>

                  <div id={"room-door-keys-#{door.id}"} class="mt-3 space-y-2">
                    <div
                      :if={door_key_requirements(door) == []}
                      class="rounded-md border border-emerald-400/20 bg-emerald-400/10 px-3 py-2 text-sm text-emerald-100"
                    >
                      Ingen nyckel krävs för den här dörren.
                    </div>

                    <div
                      :for={door_key <- door_key_requirements(door)}
                      id={"room-door-key-#{door_key.id}"}
                      class="rounded-md border border-white/10 bg-zinc-950/70 px-3 py-2"
                    >
                      <div class="flex flex-wrap items-center justify-between gap-2">
                        <div class="flex items-center gap-2">
                          <.icon name="hero-key" class="size-4 text-amber-200" />
                          <span class="text-sm font-semibold text-white">
                            {key_name(key_for(door_key))}
                          </span>
                        </div>
                        <span class={[
                          "rounded border px-2 py-0.5 text-xs font-semibold",
                          key_status_classes(key_for(door_key))
                        ]}>
                          {key_status_label(key_for(door_key))}
                        </span>
                      </div>
                      <p
                        :if={key_description(key_for(door_key))}
                        class="mt-1 text-xs leading-5 text-zinc-400"
                      >
                        {key_description(key_for(door_key))}
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <.form
                for={@room_instruction_form}
                id="room-instruction-form"
                phx-submit="save_room_instruction"
                class="mt-6"
              >
                <.input
                  field={@room_instruction_form[:instruction]}
                  id="room-instruction-input"
                  type="textarea"
                  label="Instruktion för den här episoden"
                  placeholder="Ge rummet extra kontext, krav eller nästa uppgift."
                  rows="5"
                  class="min-h-32 w-full resize-y rounded-md border border-white/15 bg-zinc-950 px-3 py-2 text-sm leading-6 text-white outline-none transition duration-200 placeholder:text-zinc-500 focus:border-red-400 focus:ring-4 focus:ring-red-500/20"
                />
                <button
                  id="save-room-instruction-button"
                  type="submit"
                  class="mt-2 inline-flex min-h-10 w-full items-center justify-center gap-2 rounded-md bg-white px-4 py-2 text-sm font-bold text-zinc-950 transition duration-200 hover:bg-red-100 focus:outline-none focus:ring-4 focus:ring-white/20"
                >
                  <.icon name="hero-chat-bubble-left-ellipsis" class="size-4" /> Spara instruktion
                </button>
              </.form>
            </div>

            <div :if={!@selected_room} id="empty-room-detail" class="text-sm leading-6 text-zinc-400">
              Välj en episod för att se status, progress och ge rummet en egen prompt.
            </div>
          </aside>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
