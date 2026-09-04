defmodule M4w.Repo.Migrations.AddArtifactsToPassages do
  use Ecto.Migration

  def change do
    create table(:artifacts) do
      add :space_id, references(:spaces, on_delete: :delete_all), null: false
      add :room_id, references(:rooms, on_delete: :nilify_all)
      add :key, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :kind, :string, null: false, default: "work_product"
      add :status, :string, null: false, default: "draft"
      add :content, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:artifacts, [:space_id])
    create index(:artifacts, [:room_id])
    create index(:artifacts, [:kind])
    create index(:artifacts, [:status])
    create unique_index(:artifacts, [:space_id, :key])

    alter table(:passages) do
      add :artifact_id, references(:artifacts, on_delete: :restrict)
      add :used_key_id, references(:keys, on_delete: :restrict)
    end

    create index(:passages, [:artifact_id])
    create index(:passages, [:used_key_id])
  end
end
