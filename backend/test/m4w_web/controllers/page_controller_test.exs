defmodule M4wWeb.PageControllerTest do
  use M4wWeb.ConnCase

  import Phoenix.LiveViewTest
  import Ecto.Query

  alias M4w.Repo
  alias M4w.World.{Door, Goal, Key, Room, Space}

  test "GET / serves the React frontend", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert html_response(conn, 200) =~ ~s(<div id="root">)
  end

  test "GET /builder", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/builder")

    assert has_element?(view, "#builder-shell")
    assert has_element?(view, "#goal-builder-form")
    assert has_element?(view, "#spaces")
    assert has_element?(view, "#empty-series-hero")
  end

  test "creates a Netflix-like series with room episodes from the builder form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/builder")

    assert has_element?(view, "#goal-builder-form")

    view
    |> form("#goal-builder-form",
      goal: %{
        title: "Bygg en varldsportal",
        description: "Planera rum, dorrar och objekt for en spelbar prototyp."
      }
    )
    |> render_submit()

    # Space design (M4w.Design) runs asynchronously — in test env it goes
    # through the free M4w.Design.Providers.Stub, which returns instantly,
    # but the LiveView still needs to await the async assign before the
    # space exists.
    render_async(view)

    goal = Repo.get_by!(Goal, title: "Bygg en varldsportal")
    space = Repo.get_by!(Space, goal_id: goal.id)
    rooms = Repo.all(from room in Room, where: room.space_id == ^space.id, order_by: room.key)

    doors =
      Door
      |> where([door], door.space_id == ^space.id)
      |> order_by([door], asc: door.inserted_at, asc: door.name)
      |> preload([door], [:room_a, :room_b, door_keys: :key])
      |> Repo.all()

    keys = Repo.all(from key in Key, where: key.space_id == ^space.id, order_by: key.name)

    # M4w.Design.Providers.Stub returns a small fixed blueprint (see
    # lib/m4w/design/providers/stub.ex) — two rooms linked by one open door,
    # no keys.
    assert Enum.map(rooms, & &1.key) == ["analysis", "implementation"]
    assert Enum.map(doors, & &1.name) == ["Grind till implementation"]
    refute Enum.any?(doors, & &1.locked)
    assert keys == []

    analysis_room = Enum.find(rooms, &(&1.key == "analysis"))

    assert has_element?(view, "#selected-series-hero")
    assert has_element?(view, "#spaces-#{space.id}")
    assert has_element?(view, "#selected_rooms-#{analysis_room.id}")
    assert has_element?(view, "#room-detail")
    assert has_element?(view, "#room-doors")
    assert has_element?(view, "#room-door-#{List.first(doors).id}")

    view
    |> form("#room-instruction-form",
      room_instruction: %{instruction: "Prioritera risker och hitta minsta trygga start."}
    )
    |> render_submit()

    assert Repo.get!(Room, analysis_room.id).metadata["instruction"] =~ "Prioritera risker"
  end
end
