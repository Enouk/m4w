defmodule M4w.Ops.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops.Space

  schema "ops_contacts" do
    field :name, :string
    field :role, :string
    field :email, :string
    field :kind_group, :string, default: "intern"
    field :rooms, {:array, :string}, default: []

    belongs_to :space, Space

    timestamps(type: :utc_datetime)
  end

  @groups ~w(intern extern ai)

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:space_id, :name, :role, :email, :kind_group, :rooms])
    |> validate_required([:space_id, :name, :kind_group])
    |> validate_inclusion(:kind_group, @groups)
    |> foreign_key_constraint(:space_id)
  end
end
