defmodule CPSIM.CP.Actions.Calls.MeterValues do
  require Logger

  alias CPSIM.CP.Connection.Messages.{Call, CallResult, CallError}

  def send(state, context, sampled_values, action_callback \\ nil) do
    Call.new(
      "MeterValues",
      %{
        connectorId: get_in(state, [:modules, CPSIM.CP.Actions, :state, :started_transaction_connector]),
        transactionId: get_in(state, [:modules, CPSIM.CP.Actions, :state, :started_transaction_id]),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        meterValues: %{
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          sampledValue: sampled_values |> Enum.map(&Map.put(&1, :context, context))
        }
      },
      __MODULE__
    )
    |> CPSIM.CP.Connection.Calls.enqueue(state)
    |> put_in([:modules, CPSIM.CP.Actions, :state, :action_callback], action_callback)
  end

  def handle_call_response(%CallResult{payload: %{}}, _call, state) do
    maybe_call_action_callback(state)
    |> then(&{:ok, &1})
  end

  def handle_call_response(%CallError{error_code: code, error_desc: desc, error_details: details}, _call, state) do
    Logger.warn(
      "Received error response from server: code=#{inspect(code)}, desc=#{inspect(desc)}, details=#{inspect(details)}"
    )

    state
    |> CPSIM.CP.Actions.skip_current_batch()
    |> then(&{:ok, &1})
  end

  defp maybe_call_action_callback(state) do
    case get_in(state, [:modules, CPSIM.CP.Actions, :state, :action_callback]) do
      action_callback when not is_nil(action_callback) ->
        state
        |> put_in([:modules, CPSIM.CP.Actions, :state, :action_callback], nil)
        |> CPSIM.CP.Actions.call_action_callback(action_callback)

      nil ->
        state
    end
  end
end
