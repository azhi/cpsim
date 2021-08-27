defmodule CPSIM.CP.Heartbeat.Calls.Heartbeat do
  alias CPSIM.CP.Connection.Messages.{Call, CallResult, CallError}

  require Logger

  def send(state) do
    Call.new("Heartbeat", %{}, __MODULE__)
    |> CPSIM.CP.Connection.Calls.enqueue(state)
  end

  def handle_call_response(%CallResult{payload: %{"currentTime" => time}}, _call, state) do
    CPSIM.CP.Connection.update_server_time(state, time)
    |> then(&{:ok, &1})
  end

  def handle_call_response(%CallResult{payload: payload}, _call, state) do
    Logger.warn("Malformed heartbeat response: #{inspect(payload)}")
    {:ok, state}
  end

  def handle_call_response(%CallError{error_code: code, error_desc: desc, error_details: details}, _call, state) do
    Logger.warn(
      "Received error response from server: code=#{inspect(code)}, desc=#{inspect(desc)}, details=#{inspect(details)}"
    )

    {:ok, state}
  end
end
