defmodule CPSIM.CP.Application do
  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [
        {Registry, keys: :unique, name: CPSIM.CP.Registry, partitions: System.schedulers_online()},
        CPSIM.CP.DynamicSupervisor
      ],
      strategy: :one_for_all
    )
  end
end
