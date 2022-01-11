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

  def add_subscriber(name, pid \\ self()) do
    GenServer.call(name, {__MODULE__, :add_subscriber, pid})
  end

  def init(opts) do
    internal_config = %InternalConfig{} = Keyword.fetch!(opts, :internal_config)
    ocpp_config = %OCPPConfig{} = Keyword.fetch!(opts, :ocpp_config)
    modules = %{} = Keyword.fetch!(opts, :modules) |> parse_modules()

    %{internal_config: internal_config, ocpp_config: ocpp_config, modules: modules, subscribers: []}
    |> Connection.init()
    |> then(&{:ok, &1})
  end

  def handle_call({__MODULE__, :handle_incoming, message}, _from, state) do
    with {:ok, message} <- Connection.Messages.decode(message) do
      {response, state} = handle_message(message, state)
      {:reply, response, state} |> notify_subscribers()
    end
  end

  def handle_call({__MODULE__, :get_state}, _from, state) do
    response_state = present_state(state)
    {:reply, response_state, state}
  end

  def handle_call({__MODULE__, :add_subscriber, pid}, _from, state) do
    Process.monitor(pid)
    state = update_in(state, [:subscribers], &[pid | &1])
    {:reply, :ok, state}
  end

  def handle_call({module, event, message}, from, state) when module in @modules do
    module.handle_call({event, message}, from, state)
    |> notify_subscribers()
  end

  def handle_info({module, event}, state) when module in @modules do
    module.handle_info(event, state)
    |> notify_subscribers()
  end

  def handle_info({module, event, data}, state) when module in @modules do
    module.handle_info({event, data}, state)
    |> notify_subscribers()
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state = update_in(state, [:subscribers], fn subscribers -> Enum.filter(subscribers, &(&1 != pid)) end)
    {:noreply, state}
  end

  defp handle_message(%Connection.Messages.Call{} = call, state) do
    Commands.handle_call(call, state)
  end

  defp handle_message(%struct{} = call_response, state)
       when struct in [Connection.Messages.CallResult, Connection.Messages.CallError] do
    Connection.handle_call_response(call_response, state)
  end

  defp notify_subscribers({:noreply, state} = ret), do: notify(:cp_update, state) |> then(fn _ -> ret end)
  defp notify_subscribers({:reply, _reply, state} = ret), do: notify(:cp_update, state) |> then(fn _ -> ret end)
  defp notify_subscribers({:stop, _reason, state} = ret), do: notify(:cp_stop, state) |> then(fn _ -> ret end)
  defp notify_subscribers({:stop, _reason, _reply, state} = ret), do: notify(:cp_stop, state) |> then(fn _ -> ret end)

  defp notify(event, state) do
    response_state = present_state(state)

    state.subscribers
    |> Enum.each(&send(&1, {event, state.internal_config.identity, response_state}))
  end

  defp present_state(state) do
    @modules
    |> Enum.reduce(state, fn module, state ->
      update_in(state, [:modules, module], fn
        nil ->
          nil

        module ->
          module
          |> update_in([:config], & &1.__struct__.format_response(&1))
          |> update_in([:state], & &1.__struct__.format_response(&1))
      end)
    end)
    |> update_in([:internal_config], &Map.from_struct/1)
    |> update_in([:internal_config, :connector_meters], &Enum.map(&1, fn {_ind, value} -> value end))
    |> update_in([:ocpp_config], &Map.from_struct/1)
    |> update_in([:ocpp_config, :items, Access.all()], &Map.from_struct/1)
    |> Map.delete(:subscribers)
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
