defmodule M4w.Design.Provider do
  @moduledoc """
  Behaviour implemented by each LLM backend that can design a blueprint from
  a fully-formed request.

  Deliberately schema-agnostic: `M4w.World` and `M4w.Ops` each build their
  own `t:request/0` (their own prompts and their own JSON schema for the
  shape they need back), so the same provider serves both domains. Claude
  (`M4w.Design.Providers.Anthropic`) is the first implementation; ChatGPT,
  Mistral, DeepSeek, etc. are meant to be added as additional modules
  implementing this same callback — see feature/design-phase.md.
  """

  @type usage :: %{input_tokens: non_neg_integer(), output_tokens: non_neg_integer()}
  @type blueprint :: map()
  @type result :: {:ok, %{blueprint: blueprint(), usage: usage()}} | {:error, term()}

  @type request :: %{
          system_prompt: String.t(),
          user_prompt: String.t(),
          tool_name: String.t(),
          tool_description: String.t(),
          schema: map()
        }

  @doc """
  Designs a blueprint by forcing a single tool call whose input schema is
  `request.schema` — the response's tool input is the blueprint.

  `opts` always includes `:model`.
  """
  @callback design(request(), keyword()) :: result()

  @doc "The provider name used for pricing lookups and generation logs."
  @callback name() :: String.t()
end
