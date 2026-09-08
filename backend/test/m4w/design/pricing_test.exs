defmodule M4w.Design.PricingTest do
  use ExUnit.Case, async: true

  alias M4w.Design.Pricing

  describe "cost_usd/3" do
    test "computes cost from input/output token usage at known rates" do
      cost =
        Pricing.cost_usd("anthropic", "claude-sonnet-5", %{
          input_tokens: 1_000_000,
          output_tokens: 1_000_000
        })

      assert Decimal.equal?(cost, Decimal.new("12.00"))
    end

    test "prices a fraction of a million tokens proportionally" do
      cost =
        Pricing.cost_usd("anthropic", "claude-haiku-4-5", %{
          input_tokens: 500_000,
          output_tokens: 0
        })

      assert Decimal.equal?(cost, Decimal.new("0.50"))
    end

    test "returns zero for an unpriced provider/model instead of raising" do
      cost =
        Pricing.cost_usd("mistral", "unknown-model", %{input_tokens: 1000, output_tokens: 1000})

      assert Decimal.equal?(cost, Decimal.new(0))
    end

    test "known?/2 reflects the pricing table" do
      assert Pricing.known?("anthropic", "claude-opus-5")
      refute Pricing.known?("mistral", "unknown-model")
    end
  end
end
