defmodule CPSIM.CP.Status.Calls.StatusNotification do
  alias CPSIM.CP.Connection.Messages.{Call, CallResult, CallError}

  require Logger

  def send(state, connector, status) do
    Call.new(
      "StatusNotification",
      %{
        connectorId: connector,
        errorCode: "NoError",
        status: format_status(status),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      __MODULE__
    )
    |> CPSIM.CP.Connection.Calls.enqueue(state)
  end

  def handle_call_response(%CallResult{payload: %{}}, _call, state) do
    {:ok, state}
  end

  def handle_call_response(%CallError{error_code: code, error_desc: desc, error_details: details}, _call, state) do
    Logger.warn(
      "Received error response from server: code=#{inspect(code)}, desc=#{inspect(desc)}, details=#{inspect(details)}"
    )

    {:ok, state}
  end

  defp format_status(:available), do: "Available"
  defp format_status(:preparing), do: "Preparing"
  defp format_status(:charging), do: "Charging"
  defp format_status(:suspended_ev), do: "SuspendedEV"
  defp format_status(:suspended_evse), do: "SuspendedEVSE"
  defp format_status(:finishing), do: "Finishing"
  defp format_status(:reserved), do: "Reserved"
  defp format_status(:unavailable), do: "Unavailable"
  defp format_status(:faulted), do: "Faulted"
end
