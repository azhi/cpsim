defmodule CPSIM.CP.Connection.Calls.BootNotification do
  alias CPSIM.CP.Connection.Messages.{Call, CallResult, CallError}

  def send(state) do
    Call.new(
      "BootNotification",
      %{
        chargePointVendor: state.internal_config.vendor,
        chargePointModel: state.internal_config.model,
        firmwareVersion: state.internal_config.fw_version
      },
      __MODULE__
    )
    |> CPSIM.CP.Connection.Calls.enqueue(state)
    |> put_in([:modules, CPSIM.CP.Connection, :state, :status], :boot_notification)
  end

  def handle_call_response(
        %CallResult{payload: %{"status" => "Accepted", "interval" => interval, "currentTime" => time}},
        _call,
        state
      ) do
    state
    |> put_in([:modules, CPSIM.CP.Connection, :state, :status], :done)
    |> CPSIM.CP.Status.report_all()
    |> CPSIM.CP.Connection.update_server_time(time)
    |> CPSIM.CP.Heartbeat.init(interval)
    |> CPSIM.CP.Actions.init()
    |> then(&{:ok, &1})
  end

  def handle_call_response(%CallResult{payload: %{"status" => "Pending", "interval" => _retry_in}}, _call, state) do
    state
    |> put_in([:modules, CPSIM.CP.Connection, :state, :status], :pending)
    |> then(&{:ok, &1})
  end

  def handle_call_response(%CallResult{payload: %{"status" => "Rejected", "interval" => retry_in}}, _call, state) do
    error_msg = "Boot notification rejected by server (perhaps servers does not know this charge point identity?)"
    state = CPSIM.CP.Connection.do_retry(error_msg, state, retry_in)
    {:ok, state}
  end

  def handle_call_response(%CallResult{payload: payload}, _call, state) do
    error_msg = "Malformed boot notification response: #{inspect(payload)}"
    state = CPSIM.CP.Connection.do_retry(error_msg, state)
    {:ok, state}
  end

  def handle_call_response(%CallError{error_code: code, error_desc: desc, error_details: details}, _call, state) do
    error_msg =
      "Received error response from server: code=#{inspect(code)}, desc=#{inspect(desc)}, details=#{inspect(details)}"

    state = CPSIM.CP.Connection.do_retry(error_msg, state)
    {:ok, state}
  end
end
