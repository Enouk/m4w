defmodule M4w.Repo.Migrations.OpsEntitiesManyToManyRooms do
  use Ecto.Migration

  @moduledoc """
  Entities become Space-scoped team roles that can staff several Rooms at
  once (e.g. the same "Backend-utvecklare" role showing up in multiple
  pipeline stages) instead of belonging to exactly one Room.
  """

  def up do
    alter table(:ops_entities) do
      add(:space_id, references(:ops_spaces, on_delete: :delete_all))
    end

    execute("""
    UPDATE ops_entities e
    SET space_id = r.space_id
    FROM ops_rooms r
    WHERE e.room_id = r.id
    """)

    create table(:ops_room_entities) do
      add(:room_id, references(:ops_rooms, on_delete: :delete_all), null: false)
      add(:entity_id, references(:ops_entities, on_delete: :delete_all), null: false)
    end

    create(unique_index(:ops_room_entities, [:room_id, :entity_id]))
    create(index(:ops_room_entities, [:entity_id]))

    execute("""
    INSERT INTO ops_room_entities (room_id, entity_id)
    SELECT room_id, id FROM ops_entities WHERE room_id IS NOT NULL
    """)

    alter table(:ops_entities) do
      remove(:room_id)
    end
  end

  def down do
    alter table(:ops_entities) do
      add(:room_id, references(:ops_rooms, on_delete: :delete_all))
    end

    execute("""
    UPDATE ops_entities e
    SET room_id = re.room_id
    FROM ops_room_entities re
    WHERE re.entity_id = e.id
    """)

    drop(table(:ops_room_entities))

    alter table(:ops_entities) do
      remove(:space_id)
    end
  end
end
