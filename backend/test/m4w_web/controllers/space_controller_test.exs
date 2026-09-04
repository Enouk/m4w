defmodule M4wWeb.SpaceControllerTest do
  use M4wWeb.ConnCase, async: true

  alias M4w.Repo
  alias M4w.World.{Goal, Space}

  describe "POST /api/spaces" do
    test "creates a goal and a space from a goal object", %{conn: conn} do
      conn =
        post(conn, ~p"/api/spaces", %{
          "goal" => %{
            "title" => "Ship the first API",
            "description" => "Expose the smallest useful creation flow.",
            "metadata" => %{"source" => "api-test"}
          }
        })

      assert %{
               "data" => %{
                 "id" => space_id,
                 "name" => "Ship the first API",
                 "description" => "Expose the smallest useful creation flow.",
                 "metadata" => %{},
                 "goal" => %{
                   "id" => goal_id,
                   "title" => "Ship the first API",
                   "description" => "Expose the smallest useful creation flow.",
                   "status" => "active",
                   "metadata" => %{"source" => "api-test"}
                 }
               }
             } = json_response(conn, 201)

      assert Repo.get!(Goal, goal_id).title == "Ship the first API"
      assert %Space{goal_id: ^goal_id, name: "Ship the first API"} = Repo.get!(Space, space_id)
    end

    test "creates a goal and a space from a goal string", %{conn: conn} do
      conn = post(conn, ~p"/api/spaces", %{"goal" => "Map a tiny world"})

      assert %{
               "data" => %{
                 "name" => "Map a tiny world",
                 "goal" => %{"title" => "Map a tiny world"}
               }
             } = json_response(conn, 201)
    end

    test "returns validation errors when the goal is missing a title", %{conn: conn} do
      conn = post(conn, ~p"/api/spaces", %{"goal" => %{"description" => "No title yet"}})

      assert %{"errors" => %{"title" => ["can't be blank"]}} = json_response(conn, 422)
    end
  end
end
