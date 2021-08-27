defmodule CPSIM.CP.Commands.TriggerMessage do
  alias CPSIM.CP.Connection.Messages.{Call, CallResult, CallError}

  def handle_call(%Call{payload: %{"requestedMessage" => message}} = call, state) do
    with :ok <- check_message(message) do
      # we are directly enqueueing messages to WS
      #
      # reply to TriggerMessage is guaranteed to be send before triggered message (as per spec),
      # because commands are processed using synchronous genserver call
      #
      # enqueued messages are `cast`ed back to WS, and will be send after finishing with genserver call
      state = enqueue_message(message, state)
      result(call, state, "Accepted")
    else
      {:error, :not_supported} ->
        result(call, state, "NotImplemented")

      {:error, :unknown_type} ->
        result(call, state, "NotImplemented")

      {:error, :wrong_type} ->
        error(call, state, "TypeConstraintViolation", "Expected requestedMessage to be a string")
    end
  end

  def handle_call(call, state) do
    error(call, state, "PropertyConstraintViolation", "TriggerMessage call missing requestedMessage")
  end

  defp check_message("BootNotification"), do: :ok
  defp check_message("Heartbeat"), do: :ok
  # TODO: support meter values / status notifications
  defp check_message("MeterValues"), do: {:error, :not_supported}
  defp check_message("StatusNotification"), do: {:error, :not_supported}
  defp check_message("DiagnosticsStatusNotification"), do: {:error, :not_supported}
  defp check_message("FirmwareStatusNotification"), do: {:error, :not_supported}
  defp check_message(message) when is_binary(message), do: {:error, :unknown_type}
  defp check_message(_message), do: {:error, :wrong_type}

  defp enqueue_message("BootNotification", state), do: CPSIM.CP.Connection.Calls.BootNotification.send(state)
  defp enqueue_message("Heartbeat", state), do: CPSIM.CP.Heartbeat.Calls.Heartbeat.send(state)

  defp result(call, state, status) do
    reply =
      CallResult.new(call, %{"status" => status})
      |> CallResult.encode()
      |> Jason.encode!()

    {{:reply, reply}, state}
  end

  defp error(call, state, code, desc, details \\ %{}) do
    reply =
      CallError.new(call, code, desc, details)
      |> CallError.encode()
      |> Jason.encode!()

    {{:reply, reply}, state}
  end
end
