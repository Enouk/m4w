defmodule M4w.Repo.Migrations.CreateOpsMailAttachments do
  use Ecto.Migration

  def change do
    create table(:ops_mail_attachments) do
      add(:mail_id, references(:ops_mails, on_delete: :delete_all), null: false)
      add(:filename, :string, null: false)
      add(:content_type, :string)
      add(:size, :integer)
      add(:blob_id, :string)
      add(:data, :binary, null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:ops_mail_attachments, [:mail_id]))
  end
end
