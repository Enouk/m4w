defmodule M4w.Design.Generation do
  @moduledoc """
  A logged attempt to design a blueprint with an LLM provider.

  Every call to a provider — successful or not — is recorded here with its
  token usage and computed cost, so spend on design generation is auditable
  from day one instead of only visible on the provider's dashboard.

  Shared across domains: a generation belongs to either a `M4w.World.Goal`
  (the MUD-builder LiveView) or a `M4w.Ops.Space` (the real REST API/React
  app), whichever asked for it — never both.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias M4w.Ops
  alias M4w.World.{Goal, Space}

  @statuses ~w(ok error)

  schema "design_generations" do
    field :provider, :string
    field :model, :string
    field :status, :string, default: "ok"
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :cost_usd, :decimal, default: Decimal.new(0)
    field :error, :string
    field :metadata, :map, default: %{}

    belongs_to :goal, Goal
    belongs_to :space, Space
    belongs_to :ops_space, Ops.Space

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(generation, attrs) do
    generation
    |> cast(attrs, [
      :goal_id,
      :space_id,
      :ops_space_id,
      :provider,
      :model,
      :status,
      :input_tokens,
      :output_tokens,
      :cost_usd,
      :error,
      :metadata
    ])
    |> validate_required([:provider, :model, :status])
    |> validate_inclusion(:status, @statuses)
    |> validate_subject_present()
    |> foreign_key_constraint(:goal_id)
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:ops_space_id)
  end

  defp validate_subject_present(changeset) do
    if get_field(changeset, :goal_id) || get_field(changeset, :ops_space_id) do
      changeset
    else
      add_error(changeset, :goal_id, "or ops_space_id must be present")
    end
  end
end
