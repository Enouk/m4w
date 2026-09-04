defmodule M4w.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      M4wWeb.Telemetry,
      M4w.Repo,
      {DNSCluster, query: Application.get_env(:m4w, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: M4w.PubSub},
      # Start a worker by calling: M4w.Worker.start_link(arg)
      # {M4w.Worker, arg},
      # Start to serve requests, typically the last entry
      M4wWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: M4w.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    M4wWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
