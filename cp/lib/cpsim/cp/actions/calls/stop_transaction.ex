defmodule CPSIM.CP.Actions.Calls.StopTransaction do
  require Logger

  alias CPSIM.CP.Connection.Messages.{Call, CallResult, CallError}

  # TODO: properly handle stop transactions without id_tag
  def send(state, id_tag \\ nil, action_callback \\ nil) do
    connector_id = get_in(state, [:modules, CPSIM.CP.Actions, :state, :started_transaction_connector])

    Call.new(
      "StopTransaction",
      %{
        idTag: id_tag,
        meterStop: get_in(state, [:internal_config, :connector_meters, connector_id]) |> trunc(),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        transactionId: get_in(state, [:modules, CPSIM.CP.Actions, :state, :started_transaction_id])
      },
      __MODULE__
    )
    |> CPSIM.CP.Connection.Calls.enqueue(state)
    |> put_in([:modules, CPSIM.CP.Actions, :state, :action_callback], action_callback)
  end

  # TODO: handle parentIdTag
  # TODO: handle expire
  def handle_call_response(%CallResult{payload: %{"idTagInfo" => %{"status" => "Accepted"}}}, _call, state) do
    state
    |> put_in([:modules, CPSIM.CP.Actions, :state, :started_transaction_id], nil)
    |> put_in([:modules, CPSIM.CP.Actions, :state, :started_transaction_connector], nil)
    |> maybe_call_action_callback()
    |> then(&{:ok, &1})
  end

  def handle_call_response(%CallResult{payload: %{"idTagInfo" => %{"status" => status}}}, _call, state)
      when status in ~w[Blocked Expired Invalid ConcurrentTx] do
    state
    |> CPSIM.CP.Actions.skip_current_batch()
    |> then(&{:ok, &1})
  end

  def handle_call_response(%CallResult{payload: %{}}, _call, state) do
    state
    |> put_in([:modules, CPSIM.CP.Actions, :state, :started_transaction_id], nil)
    |> put_in([:modules, CPSIM.CP.Actions, :state, :started_transaction_connector], nil)
    |> maybe_call_action_callback()
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
