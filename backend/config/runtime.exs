import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/m4w start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :m4w, M4wWeb.Endpoint, server: true
end

config :m4w, M4wWeb.Endpoint, http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Stalwart mail server integration (incoming mail). The poller only starts
# (see M4w.Application) when STALWART_JMAP_URL is set, so this is a no-op
# unless it's configured — e.g. in test.
config :m4w, :stalwart,
  jmap_url: System.get_env("STALWART_JMAP_URL"),
  jmap_user: System.get_env("STALWART_JMAP_USER"),
  jmap_password: System.get_env("STALWART_JMAP_PASSWORD"),
  poll_interval_ms: String.to_integer(System.get_env("STALWART_POLL_INTERVAL_MS", "10000"))

# Space design (M4w.Design). Deliberately skipped in :test so a developer's
# globally-exported ANTHROPIC_API_KEY/OPENAI_API_KEY can never make the test
# suite call a paid API — M4w.Design.provider/0 falls back to the free Stub
# provider whenever this config isn't set.
#
# DESIGN_PROVIDER forces a specific provider ("anthropic" | "openai" |
# "stub") — set this to switch providers without unsetting the other's API
# key, e.g. when one account is out of credit but its key is still valid.
# Left unset, the first provider with an API key configured wins (Anthropic,
# then OpenAI), falling back to Stub if neither is set.
if config_env() != :test do
  # `docker compose` passes through blank .env lines (e.g. `ANTHROPIC_API_KEY=`)
  # as an empty string, not an unset var — and "" is truthy in Elixir, so
  # without this it would wrongly pick that provider and send an empty key
  # instead of falling back to Stub.
  blank_to_nil = fn value -> if value in [nil, ""], do: nil, else: value end

  anthropic_api_key = System.get_env("ANTHROPIC_API_KEY") |> blank_to_nil.()
  openai_api_key = System.get_env("OPENAI_API_KEY") |> blank_to_nil.()

  {provider, default_model} =
    case System.get_env("DESIGN_PROVIDER") |> blank_to_nil.() do
      "anthropic" ->
        {M4w.Design.Providers.Anthropic, "claude-sonnet-5"}

      "openai" ->
        {M4w.Design.Providers.OpenAI, "gpt-5"}

      "stub" ->
        {M4w.Design.Providers.Stub, "stub"}

      nil ->
        cond do
          anthropic_api_key -> {M4w.Design.Providers.Anthropic, "claude-sonnet-5"}
          openai_api_key -> {M4w.Design.Providers.OpenAI, "gpt-5"}
          true -> {M4w.Design.Providers.Stub, "stub"}
        end
    end

  if provider == M4w.Design.Providers.Stub do
    require Logger

    Logger.warning(
      "Neither ANTHROPIC_API_KEY nor OPENAI_API_KEY is set - M4w.Design will use the " <>
        "free Stub provider, which always returns the same fixed blueprint regardless " <>
        "of input. Set one of them (see backend/.env.example) to use a real provider."
    )
  end

  config :m4w, :design,
    anthropic_api_key: anthropic_api_key,
    openai_api_key: openai_api_key,
    provider: provider,
    model: System.get_env("DESIGN_MODEL") |> blank_to_nil.() || default_model
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :m4w, M4w.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :m4w, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :m4w, M4wWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :m4w, M4wWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :m4w, M4wWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :m4w, M4w.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
