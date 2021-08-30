defmodule CPSIM.Backend.Repo do
  use Ecto.Repo,
    otp_app: :cpsim_backend,
    adapter: Ecto.Adapters.Postgres
end
