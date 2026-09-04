defmodule M4wWeb.PageControllerTest do
  use M4wWeb.ConnCase

  import Phoenix.LiveViewTest
  import Ecto.Query

  alias M4w.Repo
  alias M4w.World.{Door, Goal, Key, Room, Space}

  test "GET /", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#builder-shell")
    assert has_element?(view, "#goal-builder-form")
    assert has_element?(view, "#spaces")
    assert has_element?(view, "#empty-series-hero")
  end

  test "creates a Netflix-like series with room episodes from the builder form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#goal-builder-form")

    view
    |> form("#goal-builder-form",
      goal: %{
        title: "Bygg en varldsportal",
        description: "Planera rum, dorrar och objekt for en spelbar prototyp."
      }
    )
    |> render_submit()

    goal = Repo.get_by!(Goal, title: "Bygg en varldsportal")
    space = Repo.get_by!(Space, goal_id: goal.id)
    rooms = Repo.all(from room in Room, where: room.space_id == ^space.id, order_by: room.x)

    doors =
      Door
      |> where([door], door.space_id == ^space.id)
      |> order_by([door], asc: door.inserted_at, asc: door.name)
      |> preload([door], [:room_a, :room_b, door_keys: :key])
      |> Repo.all()

    keys = Repo.all(from key in Key, where: key.space_id == ^space.id, order_by: key.name)

    assert length(rooms) == 4
    assert Enum.map(rooms, & &1.name) == ["Analys", "Implementation", "Test", "Release"]

    assert Enum.map(doors, & &1.name) == [
             "Grind till implementation",
             "Testgrind",
             "Releasegrind"
           ]

    assert Enum.map(keys, & &1.name) == ["Analysbeslut", "Byggbar losning", "QA klartecken"]
    assert Enum.all?(doors, & &1.locked)
    assert doors |> List.first() |> Map.fetch!(:door_keys) |> List.first() |> Map.fetch!(:key)

    analysis_room = List.first(rooms)
    assert analysis_room.metadata["progress"] == 35
    assert analysis_room.metadata["status"] == "in_progress"

    assert has_element?(view, "#selected-series-hero")
    assert has_element?(view, "#spaces-#{space.id}")
    assert has_element?(view, "#selected_rooms-#{analysis_room.id}")
    assert has_element?(view, "#room-detail")
    assert has_element?(view, "#room-doors")
    assert has_element?(view, "#room-door-#{List.first(doors).id}")
    assert has_element?(view, "#room-door-key-#{List.first(List.first(doors).door_keys).id}")

    view
    |> form("#room-instruction-form",
      room_instruction: %{instruction: "Prioritera risker och hitta minsta trygga start."}
    )
    |> render_submit()

    assert Repo.get!(Room, analysis_room.id).metadata["instruction"] =~ "Prioritera risker"
  end
end
