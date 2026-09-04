defmodule M4w.Ops.Space do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Room, User}

  schema "ops_spaces" do
    field :name, :string
    field :address, :string
    field :category, :string
    field :goal, :string, default: ""
    field :status, :string, default: "active"

    has_many :rooms, Room
    many_to_many :users, User, join_through: "ops_user_spaces"

    timestamps(type: :utc_datetime)
  end

  def changeset(space, attrs) do
    space
    |> cast(attrs, [:name, :address, :category, :goal, :status])
    |> validate_required([:name, :address])
    |> unique_constraint(:address)
  end
end
