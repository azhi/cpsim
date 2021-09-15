defmodule CPSIM.CP.Connection do
  require Logger

  def init(state) do
    {:ok, pid} =
      __MODULE__.WS.start_link(
        url: Path.join(state.internal_config.ws_endpoint, state.internal_config.identity),
        parent: self()
      )

    true = Process.link(pid)

    state
    |> put_in([:modules, __MODULE__, :state, :ws], pid)
    |> put_in([:modules, __MODULE__, :state, :status], :ws_init)
  end

  def reset(type, state) do
    state
    |> disconnect_ws()
    |> schedule_reset(type)
    |> put_in([:modules, __MODULE__, :state, :status], :resetting)
  end

  def handle_info({:established, _conn}, state) do
    Logger.debug("Connected to OCPP server", url: state.internal_config.ws_endpoint)

    # TODO: initial messages logic - status notifications, etc in case there's no boot notification
    state
    |> maybe_send_boot_notification()
    |> then(&{:noreply, &1})
  end

  def handle_info({:lost, info}, state) do
    message =
      case get_in(state, [:modules, __MODULE__, :state, :status]) do
        :ws_init -> "Can't connect"
        _other -> "Lost connection"
      end

    Logger.debug(message <> " to OCPP server", info: inspect(info, limit: :infinity))

    state = CPSIM.CP.Status.reset_reported_at(state)

    {:noreply, state}
  end

  def handle_info(:retry, state) do
    state
    |> put_in([:modules, __MODULE__, :state, :status], :ws_init)
    |> put_in([:modules, __MODULE__, :state, :connection_error], nil)
    |> put_in([:modules, __MODULE__, :state, :retry_at], nil)
    |> maybe_send_boot_notification()
    |> then(&{:noreply, &1})
  end

  def handle_info(:reset_done, state) do
    init(state)
    |> then(&{:noreply, &1})
  end

  def handle_info({:call_timeout, call_id}, state) do
    __MODULE__.Calls.handle_call_timeout(call_id, state)
  end

  def handle_call_response(result_or_error, state) do
    __MODULE__.Calls.handle_call_response(result_or_error, state)
  end

  def update_server_time(state, current_time) do
    now = DateTime.utc_now()

    case DateTime.from_iso8601(current_time) do
      {:ok, server_time, _offset} ->
        put_in(state, [:modules, __MODULE__, :state, :current_time_diff], DateTime.diff(server_time, now, :microsecond))

      {:error, reason} ->
        Logger.error("Received error when parsing current time from server: #{inspect(reason)}")
        state
    end
  end

  def do_retry(error_message, state, retry_in \\ nil) do
    retry_in = retry_in || state.modules[__MODULE__].config.default_retry_interval
    retry_at = DateTime.utc_now() |> DateTime.add(retry_in, :second)

    Process.send_after(self(), {__MODULE__, :retry}, retry_in * 1_000)

    state
    |> put_in([:modules, __MODULE__, :state, :status], :retry)
    |> put_in([:modules, __MODULE__, :state, :connection_error], error_message)
    |> put_in([:modules, __MODULE__, :state, :retry_at], retry_at)
  end

  defp disconnect_ws(state) do
    Logger.debug("Disconnecting from OCPP server")
    __MODULE__.WS.stop(state.modules[__MODULE__].state.ws)
    put_in(state, [:modules, __MODULE__, :state, :ws], nil)
  end

  defp schedule_reset(state, type) do
    config_key =
      case type do
        "Soft" -> :soft_reboot_interval
        "Hard" -> :hard_reboot_interval
      end

    interval = state.modules[__MODULE__].config[config_key]
    Process.send_after(self(), {__MODULE__, :reset_done}, interval * 1_000)

    retry_at = DateTime.utc_now() |> DateTime.add(interval, :second)
    put_in(state, [:modules, __MODULE__, :state, :retry_at], retry_at)
  end

  defp maybe_send_boot_notification(state) do
    case get_in(state, [:modules, __MODULE__, :state, :status]) do
      :ws_init -> __MODULE__.Calls.BootNotification.send(state)
      _other -> state
    end
  end
end
