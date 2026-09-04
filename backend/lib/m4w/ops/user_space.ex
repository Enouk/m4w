defmodule M4w.Ops.UserSpace do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ops_user_spaces" do
    belongs_to :user, M4w.Ops.User
    belongs_to :space, M4w.Ops.Space

    timestamps(type: :utc_datetime)
  end

  def changeset(user_space, attrs) do
    user_space
    |> cast(attrs, [:user_id, :space_id])
    |> validate_required([:user_id, :space_id])
    |> unique_constraint([:user_id, :space_id])
  end
end
