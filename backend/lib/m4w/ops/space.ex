defmodule M4w.Ops.Space do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Goal, Room, User}

  schema "ops_spaces" do
    field :name, :string
    field :address, :string
    field :category, :string
    field :goal, :string, default: ""
    field :status, :string, default: "active"

    belongs_to :parent_goal, Goal, foreign_key: :goal_id
    has_many :rooms, Room
    many_to_many :users, User, join_through: "ops_user_spaces"

    timestamps(type: :utc_datetime)
  end

  def changeset(space, attrs) do
    space
    |> cast(attrs, [:name, :address, :category, :goal, :status, :goal_id])
    |> validate_required([:name, :address])
    |> unique_constraint(:address)
    |> foreign_key_constraint(:goal_id)
  end
end
