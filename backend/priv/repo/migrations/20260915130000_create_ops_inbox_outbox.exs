defmodule M4w.Repo.Migrations.CreateOpsInboxOutbox do
  use Ecto.Migration

  def change do
    create table(:ops_inboxes) do
      add(:space_id, references(:ops_spaces, on_delete: :delete_all), null: false)
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:ops_inboxes, [:space_id]))

    create table(:ops_outboxes) do
      add(:space_id, references(:ops_spaces, on_delete: :delete_all), null: false)
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:ops_outboxes, [:space_id]))

    execute(
      """
      INSERT INTO ops_inboxes (space_id, inserted_at, updated_at)
      SELECT id, now(), now() FROM ops_spaces
      """,
      ""
    )

    execute(
      """
      INSERT INTO ops_outboxes (space_id, inserted_at, updated_at)
      SELECT id, now(), now() FROM ops_spaces
      """,
      ""
    )

    alter table(:ops_mails) do
      add(:inbox_id, references(:ops_inboxes, on_delete: :nilify_all))
    end

    create(index(:ops_mails, [:inbox_id]))

    execute(
      """
      UPDATE ops_mails
      SET inbox_id = ops_inboxes.id
      FROM ops_inboxes
      WHERE ops_mails.space_id = ops_inboxes.space_id
      """,
      ""
    )

    alter table(:ops_outbox_messages) do
      add(:outbox_id, references(:ops_outboxes, on_delete: :nilify_all))
    end

    create(index(:ops_outbox_messages, [:outbox_id]))

    execute(
      """
      UPDATE ops_outbox_messages
      SET outbox_id = ops_outboxes.id
      FROM ops_outboxes
      WHERE ops_outbox_messages.space_id = ops_outboxes.space_id
      """,
      ""
    )
  end
end
