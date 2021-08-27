defmodule CPSIM.CP.Commands.Reset do
  alias CPSIM.CP.Connection.Messages.{Call, CallResult, CallError}

  def handle_call(%Call{payload: %{"type" => type}} = call, state) do
    with :ok <- check_type(type),
         :ok <- check_active_transaction(state) do
      state = CPSIM.CP.Connection.reset(type, state)
      result(call, state, "Accepted")
    else
      {:error, :unknown_type} ->
        error(call, state, "PropertyConstraintViolation", "Reset call has unknown type, expected Soft or Hard")

      {:error, :wrong_type} ->
        error(call, state, "TypeConstraintViolation", "Expected type to be a string")

      {:error, :active_transaction} ->
        result(call, state, "Rejected")
    end
  end

  def handle_call(call, state) do
    error(call, state, "PropertyConstraintViolation", "Reset call missing type")
  end

  defp check_type("Soft"), do: :ok
  defp check_type("Hard"), do: :ok
  defp check_type(type) when is_binary(type), do: {:error, :unknown_type}
  defp check_type(_type), do: {:error, :wrong_type}

  defp check_active_transaction(state) do
    # TODO: handle soft reset with graceful transaction stops
    # fow now, just reject resets if there is an active transaction
    if CPSIM.CP.Actions.active_transaction?(state), do: {:error, :active_transaction}, else: :ok
  end

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
