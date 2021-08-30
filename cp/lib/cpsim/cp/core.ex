defmodule CPSIM.CP.Core do
  use GenServer, restart: :transient

  alias CPSIM.CP.{InternalConfig, OCPPConfig, Actions, Commands, Connection, Heartbeat, Status}

  @modules [Actions, Commands, Connection, Heartbeat, Status]

  def start_link(opts) do
    {name_opts, opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, opts, name_opts)
  end

  def stop(name, reason \\ :normal) do
    GenServer.stop(name, reason)
  end

  def get_state(name) do
    GenServer.call(name, {__MODULE__, :get_state})
  end

  def init(opts) do
    internal_config = %InternalConfig{} = Keyword.fetch!(opts, :internal_config)
    ocpp_config = %OCPPConfig{} = Keyword.fetch!(opts, :ocpp_config)
    modules = %{} = Keyword.fetch!(opts, :modules) |> parse_modules()

    %{internal_config: internal_config, ocpp_config: ocpp_config, modules: modules}
    |> Connection.init()
    |> then(&{:ok, &1})
  end

  def handle_call({__MODULE__, :handle_incoming, message}, _from, state) do
    with {:ok, message} <- Connection.Messages.decode(message) do
      {response, state} = handle_message(message, state)
      {:reply, response, state}
    end
  end

  def handle_call({__MODULE__, :get_state}, _from, state) do
    response_state =
      @modules
      |> Enum.reduce(state, fn module, state ->
        state
        |> update_in([:modules, module, :config], &Map.from_struct/1)
        |> update_in([:modules, module, :state], &module.format_response_state/1)
      end)
      |> update_in([:internal_config], &Map.from_struct/1)
      |> update_in([:ocpp_config], &Map.from_struct/1)
      |> update_in([:ocpp_config, :items, Access.all()], &Map.from_struct/1)

    {:reply, response_state, state}
  end

  def handle_call({module, event, message}, from, state) when module in @modules do
    module.handle_call({event, message}, from, state)
  end

  def handle_info({module, event}, state) when module in @modules do
    module.handle_info(event, state)
  end

  def handle_info({module, event, data}, state) when module in @modules do
    module.handle_info({event, data}, state)
  end

  defp handle_message(%Connection.Messages.Call{} = call, state) do
    Commands.handle_call(call, state)
  end

  defp handle_message(%struct{} = call_response, state)
       when struct in [Connection.Messages.CallResult, Connection.Messages.CallError] do
    Connection.handle_call_response(call_response, state)
  end

  defp parse_modules(modules) do
    Enum.map(modules, fn
      {module, config} = item ->
        if config.__struct__ == Module.concat(module, :Config) do
          {module, %{config: config, state: Module.concat(module, :State).new(config)}}
        else
          raise_module_error(item)
        end

      other ->
        raise_module_error(other)
    end)
    |> Enum.into(%{})
  end

  defp raise_module_error(item) do
    raise(
      ArgumentError,
      "Expected modules option to contain a map where keys are simulation modules, " <>
        "and values are two-tuples of config and state, got #{inspect(item)}"
    )
  end
end
