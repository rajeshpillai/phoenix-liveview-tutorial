defmodule LiveviewLabWeb.Router do
  use LiveviewLabWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LiveviewLabWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LiveviewLabWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/lessons/streams", Lesson1StreamsLive
    live "/lessons/streaming", Lesson2StreamingLive
    live "/lessons/temporary-assigns", Lesson3TempAssignsLive
    live "/lessons/components", Lesson4ComponentsLive
    live "/lessons/pubsub", Lesson5PubsubLive
    live "/lessons/js-hooks", Lesson6JsHooksLive
    live "/notes/:lesson", NotesLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", LiveviewLabWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:liveview_lab, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LiveviewLabWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
