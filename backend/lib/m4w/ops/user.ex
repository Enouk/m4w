defmodule M4w.Ops.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Org, Space}

  schema "ops_users" do
    field :name, :string
    field :email, :string
    field :role, :string
    field :initials, :string

    belongs_to :org, Org
    many_to_many :spaces, Space, join_through: "ops_user_spaces"

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :role, :initials, :org_id])
    |> validate_required([:name, :email])
    |> unique_constraint(:email)
    |> foreign_key_constraint(:org_id)
  end
end
