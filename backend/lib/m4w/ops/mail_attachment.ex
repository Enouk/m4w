defmodule M4w.Ops.MailAttachment do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.Mail

  schema "ops_mail_attachments" do
    field :filename, :string
    field :content_type, :string
    field :size, :integer
    field :blob_id, :string
    field :data, :binary

    belongs_to :mail, Mail

    timestamps(type: :utc_datetime)
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:mail_id, :filename, :content_type, :size, :blob_id, :data])
    |> validate_required([:mail_id, :filename, :data])
  end
end
