defmodule M4w.Repo.Migrations.WidenOpsMailsTextFields do
  use Ecto.Migration

  @moduledoc """
  Inbound mail is arbitrary real-world content, but the original migrations
  typed these columns `:string` (varchar(255)): `body` became
  `varchar(255)[]`, so any paragraph over 255 characters made
  `Ops.create_inbound_mail/1` raise `string_data_right_truncation` — which
  crashed `M4w.Mail.StalwartPoller` on every poll until the app shut down.
  Widen to `:text`; subjects and attachment filenames are equally unbounded.
  """

  def change do
    alter table(:ops_mails) do
      modify :body, {:array, :text}, from: {:array, :string}, default: []
      modify :subject, :text, from: :string, null: false
    end

    alter table(:ops_mail_attachments) do
      modify :filename, :text, from: :string
    end
  end
end
