defmodule M4wWeb.Router do
  use M4wWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {M4wWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", M4wWeb do
    pipe_through :browser

    live "/", BuilderLive
    get "/test", PageController, :test_frontend
  end

  scope "/api", M4wWeb do
    pipe_through :api

    post "/spaces", RestAPI.SpaceController, :create
  end

  scope "/", M4wWeb do
    pipe_through :api

    post "/mcp", MCP.ServerController, :handle
    get "/mcp", MCP.ServerController, :unsupported
    delete "/mcp", MCP.ServerController, :unsupported
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:m4w, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: M4wWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
