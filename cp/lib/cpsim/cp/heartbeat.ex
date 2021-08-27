defmodule CPSIM.CP.Heartbeat do
  require Logger

  def format_response_state(module_state) do
    module_state
    |> Map.from_struct()
    |> Map.take([:interval, :last_message_at, :last_heartbeat_at])
  end

  defguard enabled?(state) when is_map_key(state.modules, __MODULE__)

  def init(state, interval) when enabled?(state) do
    interval = if interval == 0, do: state.modules[__MODULE__].config.default_interval, else: interval

    state
    |> put_in([:modules, __MODULE__, :state, :interval], interval)
    |> schedule_timer()
  end

  def init(state, _interval) do
    state
  end

  def handle_info(:timer, state) do
    find_latest_message_at(state)
    |> heartbeat_needed?(state)
    |> maybe_send_heartbeat(state)
    |> schedule_timer()
    |> then(&{:noreply, &1})
  end

  def update_last_message_at(state, time) do
    put_in(state, [:modules, __MODULE__, :state, :last_message_at], time)
  end

  defp find_latest_message_at(state) do
    [
      state.modules[__MODULE__].state.last_message_at,
      state.modules[__MODULE__].state.last_heartbeat_at
    ]
    |> Enum.filter(& &1)
    |> Enum.max(DateTime)
  end

  defp heartbeat_needed?(latest_message_at, state) do
    heartbeat_time = DateTime.add(latest_message_at, state.modules[__MODULE__].state.interval, :second)
    now = DateTime.utc_now()
    DateTime.compare(heartbeat_time, now) in [:lt, :eq]
  end

  defp maybe_send_heartbeat(true, state) do
    __MODULE__.Calls.Heartbeat.send(state)
    |> put_in([:modules, __MODULE__, :state, :last_heartbeat_at], DateTime.utc_now())
  end

  defp maybe_send_heartbeat(false, state) do
    state
  end

  defp schedule_timer(state) do
    abs_time = find_latest_message_at(state) |> DateTime.add(state.modules[__MODULE__].state.interval, :second)
    rel_time = DateTime.diff(abs_time, DateTime.utc_now(), :millisecond)
    rel_time = if rel_time < 0, do: 0, else: rel_time

    Process.send_after(self(), {__MODULE__, :timer}, rel_time)
    state
  end
end
