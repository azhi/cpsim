defmodule CPSIM.Backend.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      # CPSIM.Backend.Repo,
      # Start the Telemetry supervisor
      CPSIM.BackendWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: CPSIM.Backend.PubSub},
      # Start the Endpoint (http/https)
      CPSIM.BackendWeb.Endpoint
      # Start a worker by calling: CPSIM.Backend.Worker.start_link(arg)
      # {CPSIM.Backend.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CPSIM.Backend.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CPSIM.BackendWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
