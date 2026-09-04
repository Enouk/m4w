defmodule M4w.Ops.Org do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.User

  schema "ops_orgs" do
    field :name, :string

    has_many :users, User

    timestamps(type: :utc_datetime)
  end

  def changeset(org, attrs) do
    org
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
