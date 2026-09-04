defmodule M4w.Repo.Migrations.AddKeysToWorldDomainModel do
  use Ecto.Migration

  def change do
    create table(:keys) do
      add :space_id, references(:spaces, on_delete: :delete_all), null: false
      add :code, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :kind, :string, null: false, default: "condition"
      add :status, :string, null: false, default: "pending"
      add :criteria, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:keys, [:space_id])
    create index(:keys, [:kind])
    create index(:keys, [:status])
    create unique_index(:keys, [:space_id, :code])

    create table(:door_keys) do
      add :door_id, references(:doors, on_delete: :delete_all), null: false
      add :key_id, references(:keys, on_delete: :delete_all), null: false
      add :requirement_kind, :string, null: false, default: "required"
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:door_keys, [:door_id])
    create index(:door_keys, [:key_id])
    create unique_index(:door_keys, [:door_id, :key_id])
  end
end
