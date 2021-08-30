defmodule CPSIM.BackendWeb.Router do
  use CPSIM.BackendWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", CPSIM.BackendWeb do
    pipe_through :api

    resources "/cp", CPController, except: [:edit, :update, :new] do
      post "/enqueue_action_batch", CPController, :enqueue_action_batch, as: :enqueue_action_batch
    end
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:fetch_session, :protect_from_forgery]
      live_dashboard "/dashboard", metrics: CPSIM.BackendWeb.Telemetry
    end
  end
end
