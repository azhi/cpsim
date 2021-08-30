defmodule CPSIM.CP.Connection.WS do
  use WebSockex

  def start_link(opts) do
    url = Keyword.fetch!(opts, :url)
    parent = Keyword.fetch!(opts, :parent)

    WebSockex.start_link(url, __MODULE__, %{parent: parent, monitor_ref: nil},
      async: true,
      handle_initial_conn_failure: true
    )
  end

  def stop(pid) do
    WebSockex.cast(pid, :disconnect)
  end

  def send_message(pid, msg) do
    WebSockex.cast(pid, {:send, msg})
  end

  def handle_connect(conn, state) do
    state = maybe_monitor_parent(state)
    send(state.parent, {CPSIM.CP.Connection, :established, conn})
    {:ok, state}
  end

  def handle_disconnect(info, %{parent: parent}) do
    send(parent, {CPSIM.CP.Connection, :lost, info})
    {:reconnect, %{parent: parent}}
  end

  def handle_disconnect(_info, state) do
    # WS was disowned as result of being told to disconnect
    {:ok, state}
  end

  def handle_cast(:disconnect, state) do
    {:close, Map.delete(state, :parent)}
  end

  def handle_cast({:send, msg}, state) do
    {:reply, {:text, msg}, state}
  end

  def handle_frame(:ping, state) do
    {:reply, :pong, state}
  end

  def handle_frame(:pong, state) do
    {:ok, state}
  end

  def handle_frame({:ping, msg}, state) do
    {:reply, {:pong, msg}, state}
  end

  def handle_frame({:pong, _msg}, state) do
    {:ok, state}
  end

  def handle_frame({frame_type, message}, state) do
    case GenServer.call(state.parent, {CPSIM.CP.Core, :handle_incoming, message}) do
      :ok -> {:ok, state}
      {:reply, reply} -> {:reply, {frame_type, reply}, state}
      :close -> {:close, state}
      {:close, close_frame} -> {:close, close_frame, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{parent: pid} = state) do
    {:stop, reason, state}
  end

  defp maybe_monitor_parent(%{monitor_ref: nil} = state), do: %{state | monitor_ref: Process.monitor(state.parent)}
  defp maybe_monitor_parent(state), do: state
end
