defmodule M4w.Design.Pricing do
  @moduledoc """
  USD-per-million-token pricing per provider+model, used to turn API usage
  into a cost figure right after each design generation — see
  feature/design-phase.md ("hur mycket token och vad det kostar").

  Prices are each provider's first-party API rates as of 2026-09. Update
  this table when prices change or when a new provider/model is added.
  """

  @prices %{
    {"anthropic", "claude-opus-5"} => {"5.00", "25.00"},
    {"anthropic", "claude-sonnet-5"} => {"2.00", "10.00"},
    {"anthropic", "claude-haiku-4-5"} => {"1.00", "5.00"},
    {"openai", "gpt-5"} => {"1.25", "10.00"},
    {"openai", "gpt-5-mini"} => {"0.25", "2.00"},
    {"openai", "gpt-5-nano"} => {"0.05", "0.40"}
  }

  @million Decimal.new(1_000_000)

  @doc """
  Computes the USD cost of a `%{input_tokens: _, output_tokens: _}` usage map
  for the given provider+model. Returns `Decimal.new(0)` for an unknown
  provider/model pair rather than raising, since a generation should still be
  logged even if pricing hasn't been added yet.
  """
  def cost_usd(provider, model, usage) do
    case Map.fetch(@prices, {provider, model}) do
      {:ok, {input_price, output_price}} ->
        per_million(usage[:input_tokens], input_price)
        |> Decimal.add(per_million(usage[:output_tokens], output_price))
        |> Decimal.round(6)

      :error ->
        Decimal.new(0)
    end
  end

  def known?(provider, model), do: Map.has_key?(@prices, {provider, model})

  defp per_million(tokens, price_per_million) do
    (tokens || 0)
    |> Decimal.new()
    |> Decimal.div(@million)
    |> Decimal.mult(Decimal.new(price_per_million))
  end
end
