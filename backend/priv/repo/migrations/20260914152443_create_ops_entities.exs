defmodule M4w.Repo.Migrations.CreateOpsEntities do
  use Ecto.Migration

  import Ecto.Query

  def up do
    create table(:ops_entities) do
      add(:room_id, references(:ops_rooms, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:kind, :string, null: false, default: "ai")
      add(:agent_type, :string)
      add(:state, :string, null: false, default: "idle")
      add(:attributes, :map, default: %{})
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_entities, [:room_id]))

    flush()

    migrate_existing_rooms_to_entities()

    alter table(:ops_rooms) do
      remove(:entity_kind)
      remove(:entity_label)
    end
  end

  def down do
    alter table(:ops_rooms) do
      add(:entity_kind, :string, null: false, default: "ai")
      add(:entity_label, :string)
    end

    flush()

    migrate_existing_entities_to_rooms()

    drop(table(:ops_entities))
  end

  defp migrate_existing_rooms_to_entities do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      "ops_rooms"
      |> select([r], %{id: r.id, entity_kind: r.entity_kind, entity_label: r.entity_label})
      |> repo().all()

    entities =
      Enum.flat_map(rows, fn room ->
        case room.entity_kind do
          "mixed" ->
            [
              entity_row(room.id, "ai", "claude_code", room.entity_label || "Agent", now),
              entity_row(room.id, "human", nil, room.entity_label || "Person", now)
            ]

          "human" ->
            [entity_row(room.id, "human", nil, room.entity_label || "Person", now)]

          _ ->
            [entity_row(room.id, "ai", "claude_code", room.entity_label || "Agent", now)]
        end
      end)

    if entities != [] do
      repo().insert_all("ops_entities", entities)
    end
  end

  defp entity_row(room_id, kind, agent_type, name, now) do
    %{
      room_id: room_id,
      kind: kind,
      agent_type: agent_type,
      name: name,
      state: "idle",
      attributes: %{},
      inserted_at: now,
      updated_at: now
    }
  end

  defp migrate_existing_entities_to_rooms do
    entities =
      "ops_entities"
      |> select([e], %{room_id: e.room_id, kind: e.kind, name: e.name})
      |> repo().all()
      |> Enum.group_by(& &1.room_id)

    Enum.each(entities, fn {room_id, room_entities} ->
      kinds = room_entities |> Enum.map(& &1.kind) |> Enum.uniq()

      entity_kind =
        cond do
          "ai" in kinds and "human" in kinds -> "mixed"
          "human" in kinds -> "human"
          true -> "ai"
        end

      entity_label = room_entities |> List.first() |> Map.get(:name)

      "ops_rooms"
      |> where([r], r.id == ^room_id)
      |> repo().update_all(set: [entity_kind: entity_kind, entity_label: entity_label])
    end)
  end
end
