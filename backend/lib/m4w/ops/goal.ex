defmodule M4w.Ops.Goal do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.{Space, User}

  schema "ops_goals" do
    field :title, :string
    field :description, :string, default: ""
    field :status, :string, default: "active"

    belongs_to :user, User
    belongs_to :plan_space, Space
    has_many :spaces, Space, foreign_key: :goal_id

    timestamps(type: :utc_datetime)
  end

  def changeset(goal, attrs) do
    goal
    |> cast(attrs, [:user_id, :title, :description, :status, :plan_space_id])
    |> validate_required([:user_id, :title])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:plan_space_id)
  end
end
