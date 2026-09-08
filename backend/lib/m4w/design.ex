defmodule M4w.Design do
  @moduledoc """
  The design context: turns a caller-built request into a blueprint via an
  LLM provider (Claude today, more later), and keeps a cost/token audit
  trail of every attempt — see feature/design-phase.md.

  Domain-agnostic on purpose: `M4w.World` (the MUD-builder LiveView) and
  `M4w.Ops` (the real REST API/React app) each build their own
  `M4w.Design.Provider.request/0` and pass a `:goal_id` or `:ops_space_id`
  for logging — this module never references either domain's blueprint
  shape.
  """

  import Ecto.Query, warn: false

  alias M4w.Design.{Generation, Pricing}
  alias M4w.Repo

  @doc "The configured provider module, defaulting to the free `Stub` provider."
  def provider do
    Application.get_env(:m4w, :design, [])
    |> Keyword.get(:provider, M4w.Design.Providers.Stub)
  end

  @doc "The configured default model."
  def model do
    Application.get_env(:m4w, :design, [])
    |> Keyword.get(:model, "claude-sonnet-5")
  end

  @doc """
  Asks a provider to design a blueprint for `request` (see
  `M4w.Design.Provider`), logging the attempt (tokens + computed cost)
  regardless of outcome.

  `opts` accepts `:provider`/`:model` overrides and `:goal_id`/
  `:ops_space_id` to attribute the generation log to its caller.

  Returns `{:ok, blueprint, generation}` or `{:error, reason, generation}`.
  """
  def generate_blueprint(request, opts \\ []) when is_map(request) do
    provider_mod = Keyword.get(opts, :provider, provider())
    model = Keyword.get(opts, :model, model())

    case provider_mod.design(request, model: model) do
      {:ok, %{blueprint: blueprint, usage: usage}} ->
        {:ok, generation} = log_generation(opts, provider_mod, model, "ok", usage, nil)
        {:ok, blueprint, generation}

      {:error, reason} ->
        usage = %{input_tokens: 0, output_tokens: 0}

        {:ok, generation} =
          log_generation(opts, provider_mod, model, "error", usage, inspect(reason))

        {:error, reason, generation}
    end
  end

  @doc "Links a generation to the `M4w.World.Space` it ended up producing."
  def attach_space(%Generation{} = generation, space_id) do
    generation
    |> Generation.changeset(%{space_id: space_id})
    |> Repo.update()
  end

  def list_goal_generations(goal_id) do
    Generation
    |> where([g], g.goal_id == ^goal_id)
    |> order_by([g], desc: g.inserted_at)
    |> Repo.all()
  end

  def list_space_generations(space_id) do
    Generation
    |> where([g], g.space_id == ^space_id)
    |> order_by([g], desc: g.inserted_at)
    |> Repo.all()
  end

  def list_ops_space_generations(ops_space_id) do
    Generation
    |> where([g], g.ops_space_id == ^ops_space_id)
    |> order_by([g], desc: g.inserted_at)
    |> Repo.all()
  end

  def total_cost_for_goal(goal_id) do
    sum_cost(where(Generation, [g], g.goal_id == ^goal_id))
  end

  def total_cost_for_space(space_id) do
    sum_cost(where(Generation, [g], g.space_id == ^space_id))
  end

  def total_cost_for_ops_space(ops_space_id) do
    sum_cost(where(Generation, [g], g.ops_space_id == ^ops_space_id))
  end

  defp sum_cost(query) do
    query
    |> select([g], sum(g.cost_usd))
    |> Repo.one()
    |> Kernel.||(Decimal.new(0))
  end

  defp log_generation(opts, provider_mod, model, status, usage, error) do
    cost = Pricing.cost_usd(provider_mod.name(), model, usage)

    %Generation{}
    |> Generation.changeset(%{
      goal_id: Keyword.get(opts, :goal_id),
      ops_space_id: Keyword.get(opts, :ops_space_id),
      provider: provider_mod.name(),
      model: model,
      status: status,
      input_tokens: usage[:input_tokens] || 0,
      output_tokens: usage[:output_tokens] || 0,
      cost_usd: cost,
      error: error,
      metadata: %{"usage" => stringify_keys(usage)}
    })
    |> Repo.insert()
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end
end
