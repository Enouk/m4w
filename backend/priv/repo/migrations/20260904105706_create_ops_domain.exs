defmodule M4w.Repo.Migrations.CreateOpsDomain do
  use Ecto.Migration

  def change do
    create table(:ops_orgs) do
      add(:name, :string, null: false)
      timestamps(type: :utc_datetime)
    end

    create table(:ops_users) do
      add(:org_id, references(:ops_orgs, on_delete: :nilify_all))
      add(:name, :string, null: false)
      add(:email, :string, null: false)
      add(:role, :string)
      add(:initials, :string)
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:ops_users, [:email]))

    create table(:ops_spaces) do
      add(:name, :string, null: false)
      add(:address, :string, null: false)
      add(:category, :string)
      add(:goal, :text, default: "")
      add(:status, :string, default: "active")
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:ops_spaces, [:address]))

    create table(:ops_user_spaces) do
      add(:user_id, references(:ops_users, on_delete: :delete_all), null: false)
      add(:space_id, references(:ops_spaces, on_delete: :delete_all), null: false)
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:ops_user_spaces, [:user_id, :space_id]))

    create table(:ops_rooms) do
      add(:space_id, references(:ops_spaces, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:position, :integer, null: false, default: 0)
      add(:entity_kind, :string, null: false, default: "ai")
      add(:entity_label, :string)
      add(:subgoal, :string)
      add(:key, :string)
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_rooms, [:space_id]))

    create table(:ops_items) do
      add(:room_id, references(:ops_rooms, on_delete: :delete_all), null: false)
      add(:title, :string, null: false)
      add(:meta, :string)
      add(:state, :string, null: false, default: "waiting")
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_items, [:room_id]))

    create table(:ops_passages) do
      add(:space_id, references(:ops_spaces, on_delete: :delete_all), null: false)
      add(:item_id, references(:ops_items, on_delete: :nilify_all))
      add(:from_room_id, references(:ops_rooms, on_delete: :nilify_all))
      add(:to_room_id, references(:ops_rooms, on_delete: :nilify_all))
      add(:text, :string, null: false)
      add(:occurred_at, :utc_datetime, null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_passages, [:space_id]))

    create table(:ops_artifacts) do
      add(:space_id, references(:ops_spaces, on_delete: :delete_all), null: false)
      add(:room_id, references(:ops_rooms, on_delete: :nilify_all))
      add(:title, :string, null: false)
      add(:kind, :string, null: false)
      add(:status, :string, null: false)
      add(:created_by, :string)
      add(:size, :string)
      add(:url, :string)
      add(:occurred_at, :utc_datetime, null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_artifacts, [:space_id]))

    create table(:ops_contacts) do
      add(:space_id, references(:ops_spaces, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:role, :string)
      add(:email, :string)
      add(:kind_group, :string, null: false, default: "intern")
      add(:rooms, {:array, :string}, default: [])
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_contacts, [:space_id]))

    create table(:ops_meetings) do
      add(:space_id, references(:ops_spaces, on_delete: :delete_all), null: false)
      add(:title, :string, null: false)
      add(:occurred_at, :utc_datetime, null: false)
      add(:status, :string, null: false, default: "planerat")
      add(:location, :string)
      add(:attendees, {:array, :map}, default: [])
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_meetings, [:space_id]))

    create table(:ops_decisions) do
      add(:meeting_id, references(:ops_meetings, on_delete: :delete_all), null: false)
      add(:text, :string, null: false)
      add(:outcome, :string)
      add(:votes, :string)
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_decisions, [:meeting_id]))

    create table(:ops_compliance_checks) do
      add(:space_id, references(:ops_spaces, on_delete: :delete_all), null: false)
      add(:title, :string, null: false)
      add(:ref, :string)
      add(:status, :string, null: false, default: "pagar")
      add(:description, :string)
      add(:state, :string)
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_compliance_checks, [:space_id]))

    create table(:ops_verifications) do
      add(:space_id, references(:ops_spaces, on_delete: :delete_all), null: false)
      add(:ver, :string, null: false)
      add(:occurred_at, :utc_datetime, null: false)
      add(:supplier, :string)
      add(:amount, :string)
      add(:status, :string, null: false, default: "bokford")
      add(:archive_until, :string)
      add(:trace_from_room_id, references(:ops_rooms, on_delete: :nilify_all))
      add(:trace_to_room_id, references(:ops_rooms, on_delete: :nilify_all))
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:ops_verifications, [:ver]))
    create(index(:ops_verifications, [:space_id]))

    create table(:ops_outbox_messages) do
      add(:space_id, references(:ops_spaces, on_delete: :delete_all), null: false)
      add(:state, :string, null: false, default: "queued")
      add(:from, :string)
      add(:to, :string)
      add(:subject, :string)
      add(:preview, :text)
      add(:status_note, :string)
      add(:passage_note, :string)
      add(:occurred_at, :utc_datetime, null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_outbox_messages, [:space_id]))

    create table(:ops_mails) do
      add(:space_id, references(:ops_spaces, on_delete: :nilify_all))
      add(:room_id, references(:ops_rooms, on_delete: :nilify_all))
      add(:from, :string, null: false)
      add(:from_email, :string)
      add(:subject, :string, null: false)
      add(:body, {:array, :string}, default: [])
      add(:occurred_at, :utc_datetime, null: false)
      add(:confidence, :string)
      add(:note, :string)
      add(:reason, :string)
      add(:status, :string, null: false, default: "unclassified")
      add(:purpose, :string, null: false, default: "inbox")
      add(:use, :boolean)
      add(:replay_room_id, references(:ops_rooms, on_delete: :nilify_all))
      add(:replay_confidence, :integer)
      add(:replay_key, :string)
      add(:replay_uncertain, :boolean, default: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_mails, [:space_id]))
    create(index(:ops_mails, [:status]))
    create(index(:ops_mails, [:purpose]))

    alter table(:ops_items) do
      add(:source_mail_id, references(:ops_mails, on_delete: :nilify_all))
    end
  end
end
