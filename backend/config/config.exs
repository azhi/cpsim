# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :cpsim_backend,
  namespace: CPSIM.Backend,
  ecto_repos: [CPSIM.Backend.Repo]

# Configures the endpoint
config :cpsim_backend, CPSIM.BackendWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "+Xy7U0Bc/vVIJMPnW6OtPnpRtJXK0pArxIyphH4BKNUbRLKv10JTV9wGYU591u6v",
  render_errors: [view: CPSIM.BackendWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: CPSIM.Backend.PubSub,
  live_view: [signing_salt: "HV8KldtG"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
