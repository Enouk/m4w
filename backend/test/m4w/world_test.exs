defmodule M4w.WorldTest do
  use M4w.DataCase, async: true

  alias M4w.Repo
  alias M4w.World
  alias M4w.World.{Artifact, Door, DoorKey, Entity, Goal, Key, Passage, Room, Space}

  describe "world domain model" do
    test "creates a connected goal, space, rooms, door, keys, artifact, entity, and passages" do
      assert {:ok, %Goal{} = goal} =
               World.create_goal(%{
                 title: "Find the lantern",
                 description: "Reach the cellar and bring back light."
               })

      assert {:ok, %Space{} = space} =
               World.create_space(%{
                 goal_id: goal.id,
                 name: "Old house",
                 metadata: %{"mood" => "quiet"}
               })

      assert {:ok, %Room{} = hall} =
               World.create_room(%{
                 space_id: space.id,
                 key: "hall",
                 name: "Hall",
                 x: 0,
                 y: 0
               })

      assert {:ok, %Room{} = cellar} =
               World.create_room(%{
                 space_id: space.id,
                 key: "cellar",
                 name: "Cellar",
                 x: 0,
                 y: -1
               })

      assert {:ok, %Door{} = door} =
               World.create_door(%{
                 space_id: space.id,
                 room_a_id: hall.id,
                 room_b_id: cellar.id,
                 name: "Cellar hatch",
                 locked: true,
                 state: "closed"
               })

      assert {:ok, %Key{} = key} =
               World.create_key(%{
                 space_id: space.id,
                 code: "cellar_key",
                 name: "Cellar key",
                 kind: "permission",
                 status: "satisfied",
                 criteria: %{"evidence" => "User approved cellar access"}
               })

      assert {:ok, %DoorKey{} = door_key} =
               World.require_key_for_door(door, key, %{requirement_kind: "required"})

      assert {:ok, %Entity{} = lantern} =
               World.create_entity(%{
                 space_id: space.id,
                 room_id: cellar.id,
                 name: "Lantern",
                 kind: "item",
                 attributes: %{"portable" => true}
               })

      assert {:ok, %Artifact{} = transition_notes} =
               World.create_artifact(%{
                 space_id: space.id,
                 room_id: hall.id,
                 key: "cellar_transition_notes",
                 name: "Cellar transition notes",
                 kind: "decision",
                 status: "accepted",
                 content: %{"summary" => "Approved move from hall to cellar"}
               })

      assert {:ok, %Passage{} = down} =
               World.create_passage(%{
                 space_id: space.id,
                 from_room_id: hall.id,
                 to_room_id: cellar.id,
                 door_id: door.id,
                 artifact_id: transition_notes.id,
                 used_key_id: key.id,
                 direction: "down",
                 conditions: %{"requires" => "cellar_key"}
               })

      assert {:ok, %Passage{} = up} =
               World.create_passage(%{
                 space_id: space.id,
                 from_room_id: cellar.id,
                 to_room_id: hall.id,
                 door_id: door.id,
                 artifact_id: transition_notes.id,
                 used_key_id: key.id,
                 direction: "up"
               })

      loaded_space =
        space
        |> Repo.preload([:goal, :rooms, :doors, :keys, :artifacts, :entities, :passages])

      assert loaded_space.goal.id == goal.id
      assert Enum.map(loaded_space.rooms, & &1.key) |> Enum.sort() == ["cellar", "hall"]
      assert Enum.map(loaded_space.doors, & &1.name) == ["Cellar hatch"]
      assert Enum.map(loaded_space.keys, & &1.code) == ["cellar_key"]
      assert Enum.map(loaded_space.artifacts, & &1.key) == ["cellar_transition_notes"]
      assert Enum.map(loaded_space.entities, & &1.name) == ["Lantern"]
      assert Enum.map(loaded_space.passages, & &1.direction) |> Enum.sort() == ["down", "up"]

      assert World.list_goal_spaces(goal) == [space]
      assert World.list_space_rooms(space) == [cellar, hall]
      assert World.list_space_doors(space) == [door]
      assert World.list_space_keys(space) == [key]
      assert World.list_space_artifacts(space) == [transition_notes]
      assert World.list_required_keys_for_door(door) == [key]
      assert World.list_door_key_requirements(door) == [Repo.preload(door_key, :key)]
      assert World.list_room_artifacts(hall) == [transition_notes]
      assert World.list_room_entities(cellar) == [lantern]
      assert World.list_room_passages(hall) == [down]
      assert World.list_room_passages(cellar) == [up]
    end

    test "requires core fields" do
      assert %{title: ["can't be blank"]} = errors_on(World.change_goal(%Goal{}))

      assert %{goal_id: ["can't be blank"], name: ["can't be blank"]} =
               errors_on(World.change_space(%Space{}))

      assert %{space_id: ["can't be blank"], key: ["can't be blank"], name: ["can't be blank"]} =
               errors_on(World.change_room(%Room{}))

      assert %{
               space_id: ["can't be blank"],
               room_a_id: ["can't be blank"],
               room_b_id: ["can't be blank"],
               name: ["can't be blank"]
             } = errors_on(World.change_door(%Door{}))

      assert %{space_id: ["can't be blank"], code: ["can't be blank"], name: ["can't be blank"]} =
               errors_on(World.change_key(%Key{}))

      assert %{space_id: ["can't be blank"], key: ["can't be blank"], name: ["can't be blank"]} =
               errors_on(World.change_artifact(%Artifact{}))

      assert %{door_id: ["can't be blank"], key_id: ["can't be blank"]} =
               errors_on(World.change_door_key(%DoorKey{}))

      assert %{space_id: ["can't be blank"], name: ["can't be blank"]} =
               errors_on(World.change_entity(%Entity{}))

      assert %{
               space_id: ["can't be blank"],
               from_room_id: ["can't be blank"],
               to_room_id: ["can't be blank"],
               artifact_id: ["can't be blank"],
               used_key_id: ["can't be blank"],
               direction: ["can't be blank"]
             } = errors_on(World.change_passage(%Passage{}))
    end

    test "doors and passages must connect two different rooms" do
      assert %{room_b_id: ["must differ from room_a_id"]} =
               errors_on(World.change_door(%Door{}, %{room_a_id: 1, room_b_id: 1}))

      assert %{to_room_id: ["must differ from from_room_id"]} =
               errors_on(World.change_passage(%Passage{}, %{from_room_id: 1, to_room_id: 1}))
    end

    test "a key requirement must belong to the same space as the door" do
      assert {:ok, goal} = World.create_goal(%{title: "Ship safely"})
      assert {:ok, first_space} = World.create_space(%{goal_id: goal.id, name: "Build"})
      assert {:ok, second_space} = World.create_space(%{goal_id: goal.id, name: "Release"})

      assert {:ok, first_room} =
               World.create_room(%{space_id: first_space.id, key: "analysis", name: "Analysis"})

      assert {:ok, second_room} =
               World.create_room(%{space_id: first_space.id, key: "test", name: "Test"})

      assert {:ok, door} =
               World.create_door(%{
                 space_id: first_space.id,
                 room_a_id: first_room.id,
                 room_b_id: second_room.id,
                 name: "Test gate"
               })

      assert {:ok, key} =
               World.create_key(%{
                 space_id: second_space.id,
                 code: "qa_signoff",
                 name: "QA sign-off"
               })

      assert {:error, changeset} = World.require_key_for_door(door, key)
      assert %{key_id: ["must belong to the same space as the door"]} = errors_on(changeset)
    end

    test "an artifact room must belong to the same space as the artifact" do
      assert {:ok, goal} = World.create_goal(%{title: "Keep traceability"})
      assert {:ok, first_space} = World.create_space(%{goal_id: goal.id, name: "Build"})
      assert {:ok, second_space} = World.create_space(%{goal_id: goal.id, name: "Audit"})

      assert {:ok, room} =
               World.create_room(%{space_id: first_space.id, key: "analysis", name: "Analysis"})

      assert {:error, changeset} =
               World.create_artifact(%{
                 space_id: second_space.id,
                 room_id: room.id,
                 key: "handoff",
                 name: "Handoff"
               })

      assert %{room_id: ["must belong to the same space as the artifact"]} = errors_on(changeset)
    end

    test "a passage records an artifact and a door key from the same space" do
      assert {:ok, goal} = World.create_goal(%{title: "Pass safely"})
      assert {:ok, space} = World.create_space(%{goal_id: goal.id, name: "Delivery"})

      assert {:ok, analysis} =
               World.create_room(%{space_id: space.id, key: "analysis", name: "Analysis"})

      assert {:ok, test} = World.create_room(%{space_id: space.id, key: "test", name: "Test"})

      assert {:ok, door} =
               World.create_door(%{
                 space_id: space.id,
                 room_a_id: analysis.id,
                 room_b_id: test.id,
                 name: "Test gate",
                 locked: true
               })

      assert {:ok, artifact} =
               World.create_artifact(%{
                 space_id: space.id,
                 room_id: analysis.id,
                 key: "analysis_report",
                 name: "Analysis report"
               })

      assert {:ok, key} =
               World.create_key(%{
                 space_id: space.id,
                 code: "qa_signoff",
                 name: "QA sign-off"
               })

      assert {:error, changeset} =
               World.create_passage(%{
                 space_id: space.id,
                 from_room_id: analysis.id,
                 to_room_id: test.id,
                 door_id: door.id,
                 artifact_id: artifact.id,
                 used_key_id: key.id,
                 direction: "forward"
               })

      assert %{used_key_id: ["must be required by the passage door"]} = errors_on(changeset)

      assert {:ok, _door_key} = World.require_key_for_door(door, key)

      assert {:ok, %Passage{} = passage} =
               World.create_passage(%{
                 space_id: space.id,
                 from_room_id: analysis.id,
                 to_room_id: test.id,
                 door_id: door.id,
                 artifact_id: artifact.id,
                 used_key_id: key.id,
                 direction: "forward"
               })

      assert Repo.preload(passage, [:artifact, :used_key]).artifact == artifact
      assert Repo.preload(passage, [:artifact, :used_key]).used_key == key
    end
  end

  describe "space JSON schema" do
    test "exposes a JSON-encodable schema for generated spaces" do
      schema = World.space_json_schema()

      assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
      assert schema["$id"] == "https://m4w.local/schemas/world/space-blueprint.schema.json"

      assert schema["required"] == [
               "space",
               "rooms",
               "doors",
               "keys",
               "artifacts",
               "entities",
               "passages"
             ]

      assert Map.keys(schema["properties"]) |> Enum.sort() == [
               "artifacts",
               "doors",
               "entities",
               "goal",
               "keys",
               "passages",
               "rooms",
               "space"
             ]

      assert Jason.decode!(World.space_json_schema_json()) == schema
    end

    test "uses stable generation references instead of database ids" do
      defs = World.space_json_schema()["$defs"]

      assert defs["room"]["required"] == ["key", "name"]
      assert defs["key"]["required"] == ["code", "name"]
      assert defs["door"]["required"] == ["name", "room_a_key", "room_b_key"]
      assert defs["door_key"]["required"] == ["key_code"]
      assert defs["artifact"]["required"] == ["key", "name"]

      assert defs["passage"]["required"] == [
               "from_room_key",
               "to_room_key",
               "artifact_key",
               "used_key_code",
               "direction"
             ]

      assert defs["door"]["properties"]["room_a_key"]["pattern"] == "^[a-z][a-z0-9_\\-]*$"
      assert defs["door"]["properties"]["room_b_key"]["pattern"] == "^[a-z][a-z0-9_\\-]*$"
      assert defs["door_key"]["properties"]["key_code"]["pattern"] == "^[a-z][a-z0-9_\\-]*$"
      assert defs["entity"]["properties"]["room_key"]["type"] == ["string", "null"]
      assert defs["artifact"]["properties"]["room_key"]["type"] == ["string", "null"]
      assert defs["passage"]["properties"]["door_name"]["type"] == ["string", "null"]
      assert defs["passage"]["properties"]["artifact_key"]["pattern"] == "^[a-z][a-z0-9_\\-]*$"
      assert defs["passage"]["properties"]["used_key_code"]["pattern"] == "^[a-z][a-z0-9_\\-]*$"

      refute Map.has_key?(defs["door"]["properties"], "room_a_id")
      refute Map.has_key?(defs["door"]["properties"], "room_b_id")
      refute Map.has_key?(defs["passage"]["properties"], "from_room_id")
      refute Map.has_key?(defs["passage"]["properties"], "to_room_id")
      refute Map.has_key?(defs["passage"]["properties"], "artifact_id")
      refute Map.has_key?(defs["passage"]["properties"], "used_key_id")
    end
  end
end
