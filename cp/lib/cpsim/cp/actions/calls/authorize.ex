defmodule CPSIM.CP.Actions.Calls.Authorize do
  require Logger

  alias CPSIM.CP.Connection.Messages.{Call, CallResult, CallError}

  def send(state, id_tag, action_callback \\ nil) do
    Call.new("Authorize", %{idTag: id_tag}, __MODULE__)
    |> CPSIM.CP.Connection.Calls.enqueue(state)
    |> put_in([:modules, CPSIM.CP.Actions, :state, :action_callback], action_callback)
  end

  # TODO: handle parentIdTag
  # TODO: handle expire
  def handle_call_response(
        %CallResult{payload: %{"idTagInfo" => %{"status" => "Accepted"}}},
        _call,
        state
      ) do
    maybe_call_action_callback(state)
    |> then(&{:ok, &1})
  end

  def handle_call_response(%CallResult{payload: %{"idTagInfo" => %{"status" => status}}}, _call, state)
      when status in ~w[Blocked Expired Invalid] do
    state
    |> CPSIM.CP.Actions.skip_current_batch()
    |> then(&{:ok, &1})
  end

  def handle_call_response(%CallResult{payload: payload}, _call, state) do
    Logger.warn("Malformed authorize response: #{inspect(payload)}")

    state
    |> CPSIM.CP.Actions.skip_current_batch()
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
