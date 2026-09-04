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

  pipeline :ops_auth do
    plug M4wWeb.Plugs.OpsAuth
  end

  pipeline :ops_space_access do
    plug M4wWeb.Plugs.OpsSpaceAccess
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

  scope "/api/v1", M4wWeb.Ops do
    pipe_through :api

    post "/auth/login", AuthController, :login
  end

  scope "/api/v1", M4wWeb.Ops do
    pipe_through [:api, :ops_auth]

    post "/auth/logout", AuthController, :logout
    get "/me", AuthController, :me

    get "/space-categories", SpaceCategoryController, :index

    get "/spaces", SpaceController, :index
    post "/spaces", SpaceController, :create

    post "/inbound-mail", MailController, :inbound
    get "/mail/:mailId", MailController, :show

    get "/items/:itemId", ItemController, :show
    patch "/items/:itemId", ItemController, :update

    get "/artifacts/:artifactId", ArtifactController, :show

    get "/meetings/:meetingId", MeetingController, :show

    get "/inbox", GlobalInboxController, :index
    get "/unclassified", GlobalInboxController, :unclassified
    post "/unclassified/:mailId/assign", GlobalInboxController, :assign

    get "/contacts", ContactController, :global_index

    get "/processes", ProcessController, :index

    scope "/spaces/:spaceId" do
      pipe_through :ops_space_access

      get "/", SpaceController, :show
      patch "/", SpaceController, :update
      delete "/", SpaceController, :delete

      get "/context-mails", ContextMailController, :index
      patch "/context-mails/:mailId", ContextMailController, :update

      post "/generate", SpaceController, :generate

      get "/rooms", RoomController, :index
      post "/rooms", RoomController, :create
      patch "/rooms/:roomId", RoomController, :update
      delete "/rooms/:roomId", RoomController, :delete

      get "/rooms/:roomId/items", ItemController, :index

      get "/passages", PassageController, :index
      post "/passages", PassageController, :create

      get "/artifacts", ArtifactController, :index

      get "/inbox", MailController, :space_inbox

      get "/replay-batch", ReplayController, :batch
      post "/replay", ReplayController, :run

      get "/outbox", OutboxController, :index
      post "/outbox/:messageId/approve", OutboxController, :approve
      patch "/outbox/:messageId", OutboxController, :update
      delete "/outbox/:messageId", OutboxController, :cancel

      get "/contacts", ContactController, :index

      get "/meetings", MeetingController, :index
      get "/decisions", DecisionController, :index

      get "/compliance", ComplianceController, :index
      get "/verifications", VerificationController, :index
    end
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
