defmodule CPSIM.CP.DynamicSupervisor do
  # Automatically defines child_spec/1
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def launch(opts) do
    internal_config = %CPSIM.CP.InternalConfig{} = Keyword.fetch!(opts, :internal_config)
    opts = Keyword.put(opts, :name, via(internal_config.identity))
    DynamicSupervisor.start_child(__MODULE__, {CPSIM.CP, opts})
  end

  def via(identity) do
    {:via, Registry, {CPSIM.CP.Registry, identity}}
  end
end
