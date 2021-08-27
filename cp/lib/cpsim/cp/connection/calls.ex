defmodule CPSIM.CP.Connection.Calls do
  alias CPSIM.CP.Connection.Messages.Call

  require CPSIM.CP.Heartbeat
  alias CPSIM.CP.Heartbeat

  require Logger

  def enqueue(%Call{direction: :outgoing} = call, state) do
    update_in(state, [:modules, CPSIM.CP.Connection, :state, :outgoing_call_queue], fn queue ->
      queue ++ [call]
    end)
    |> send_first_in_queue()
  end

  def handle_call_timeout(call_id, state) do
    get_and_update_in(state, [:modules, CPSIM.CP.Connection, :state, :outgoing_call_queue], fn
      [%Call{sent: true, id: ^call_id} = call | rest] ->
        # retry sending call
        call = do_send(call, state)
        {!heartbeat?(call), [call | rest]}

      queue ->
        # timer was triggered too late, can happen if there's race condition between handle_call_response and
        # handle_call_timeout
        #
        # we can safely ignore those triggers
        {false, queue}
    end)
    |> maybe_update_heartbeat()
    |> then(&{:noreply, &1})
  end

  def handle_call_response(result_or_error, state) do
    {call, state} = match_response_with_first(result_or_error.id, state)
    {response, state} = call_handler(result_or_error, call, state)
    state = send_first_in_queue(state)
    {response, state}
  end

  defp match_response_with_first(id, state) do
    get_and_update_in(state, [:modules, CPSIM.CP.Connection, :state, :outgoing_call_queue], fn
      [%Call{sent: true, id: ^id} = call | rest] ->
        call = disable_timeout_timer(call)
        {call, rest}

      [%Call{sent: true, id: other_id} = call | rest] ->
        Logger.warn(
          "Unexpected server behaviour: waiting for response for call id=#{other_id}, received response for call id=#{id}"
        )

        {nil, [call | rest]}

      [%Call{sent: false} = call | rest] ->
        Logger.warn("Unexpected server behaviour: no calls awaiting response, received response for call id=#{id}")
        {nil, [call | rest]}

      [] ->
        Logger.warn("Unexpected server behaviour: no calls awaiting response, received response for call id=#{id}")
        {nil, []}
    end)
  end

  defp call_handler(_result_or_error, nil, state) do
    # result_or_error was not matched with call we expect, do nothing
    {:ok, state}
  end

  defp call_handler(result_or_error, call, state) do
    call.handler.handle_call_response(result_or_error, call, state)
  end

  defp send_first_in_queue(state) do
    get_and_update_in(state, [:modules, CPSIM.CP.Connection, :state, :outgoing_call_queue], fn
      [%Call{sent: false} = call | rest] ->
        call = do_send(call, state)
        {!heartbeat?(call), [call | rest]}

      [%Call{sent: true} = call | rest] ->
        {false, [call | rest]}

      [] ->
        {false, []}
    end)
    |> maybe_update_heartbeat()
  end

  defp do_send(call, state) do
    with :ok <-
           CPSIM.CP.Connection.WS.send_message(
             state.modules[CPSIM.CP.Connection].state.ws,
             Call.encode(call) |> Jason.encode!()
           ) do
      tref =
        Process.send_after(
          self(),
          {CPSIM.CP.Connection, :call_timeout, call.id},
          state.modules[CPSIM.CP.Connection].config.call_timeout_interval * 1_000
        )

      %{call | sent: true, timeout_timer: tref}
    end
  end

  defp disable_timeout_timer(call) do
    :ok = Process.cancel_timer(call.timeout_timer, async: true, info: false)
    %{call | timeout_timer: nil}
  end

  defp heartbeat?(%Call{action: "Heartbeat"}), do: true
  defp heartbeat?(%Call{}), do: false

  # update heartbeat timestamp if any message was sent and heartbeat module is enabled
  defp maybe_update_heartbeat({true, state}) when Heartbeat.enabled?(state),
    do: CPSIM.CP.Heartbeat.update_last_message_at(state, DateTime.utc_now())

  defp maybe_update_heartbeat({_other, state}), do: state
end
