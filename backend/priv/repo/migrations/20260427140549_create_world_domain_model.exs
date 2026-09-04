defmodule M4w.Repo.Migrations.CreateWorldDomainModel do
  use Ecto.Migration

  def change do
    create table(:goals) do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "active"
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create table(:spaces) do
      add :goal_id, references(:goals, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:spaces, [:goal_id])
    create unique_index(:spaces, [:goal_id, :name])

    create table(:rooms) do
      add :space_id, references(:spaces, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :kind, :string, null: false, default: "place"
      add :x, :integer
      add :y, :integer
      add :z, :integer
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:rooms, [:space_id])
    create unique_index(:rooms, [:space_id, :key])

    create table(:doors) do
      add :space_id, references(:spaces, on_delete: :delete_all), null: false
      add :room_a_id, references(:rooms, on_delete: :delete_all), null: false
      add :room_b_id, references(:rooms, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :state, :string, null: false, default: "open"
      add :locked, :boolean, null: false, default: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:doors, [:space_id])
    create index(:doors, [:room_a_id])
    create index(:doors, [:room_b_id])

    create constraint(:doors, :doors_room_a_and_room_b_must_differ,
             check: "room_a_id <> room_b_id"
           )

    create table(:entities) do
      add :space_id, references(:spaces, on_delete: :delete_all), null: false
      add :room_id, references(:rooms, on_delete: :nilify_all)
      add :name, :string, null: false
      add :description, :text
      add :kind, :string, null: false, default: "thing"
      add :state, :string, null: false, default: "idle"
      add :attributes, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:entities, [:space_id])
    create index(:entities, [:room_id])
    create index(:entities, [:kind])

    create table(:passages) do
      add :space_id, references(:spaces, on_delete: :delete_all), null: false
      add :from_room_id, references(:rooms, on_delete: :delete_all), null: false
      add :to_room_id, references(:rooms, on_delete: :delete_all), null: false
      add :door_id, references(:doors, on_delete: :nilify_all)
      add :direction, :string, null: false
      add :name, :string
      add :description, :text
      add :conditions, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:passages, [:space_id])
    create index(:passages, [:from_room_id])
    create index(:passages, [:to_room_id])
    create index(:passages, [:door_id])
    create unique_index(:passages, [:space_id, :from_room_id, :direction])

    create constraint(:passages, :passages_from_room_and_to_room_must_differ,
             check: "from_room_id <> to_room_id"
           )
  end
end
