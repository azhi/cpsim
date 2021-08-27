defmodule CPSIM.CP.Status do
  defguardp enabled?(state) when is_map_key(state.modules, __MODULE__)

  def format_response_state(module_state) do
    module_state
    |> Map.from_struct()
    |> Map.take([:status, :status_reported_at, :connector_statuses, :connector_statuses_reported_at])
  end

  def reset_reported_at(state) when enabled?(state) do
    state
    |> put_in([:modules, __MODULE__, :state, :status_reported_at], nil)
    |> update_in(
      [:modules, __MODULE__, :state, :connector_statuses_reported_at],
      &(Enum.map(&1, fn {c, _old} -> {c, nil} end) |> Enum.into(%{}))
    )
  end

  def reset_reported_at(state) do
    state
  end

  def report_all(state) when enabled?(state) do
    state =
      if is_nil(get_in(state, [:modules, __MODULE__, :state, :status_reported_at])) do
        status = get_in(state, [:modules, __MODULE__, :state, :status])
        change_status(0, status, state)
      else
        state
      end

    get_in(state, [:modules, __MODULE__, :state, :connector_statuses])
    |> Enum.reduce(state, fn {connector, status}, state ->
      if is_nil(get_in(state, [:modules, __MODULE__, :state, :connector_statuses_reported_at, connector])) do
        change_status(connector, status, state)
      else
        state
      end
    end)
  end

  def report_all(state) do
    state
  end

  # TODO: fault error codes
  # TODO: MinimumStatusDuration config & logic
  def change_status(connector \\ 0, new_status, state)

  def change_status(0, new_status, state) when enabled?(state) do
    check_status!(0, new_status)

    state
    |> put_in([:modules, __MODULE__, :state, :status], new_status)
    |> put_in([:modules, __MODULE__, :state, :status_reported_at], DateTime.utc_now())
    |> __MODULE__.Calls.StatusNotification.send(0, new_status)
  end

  def change_status(connector, new_status, state) when enabled?(state) do
    check_status!(connector, new_status)

    state
    |> put_in([:modules, __MODULE__, :state, :connector_statuses, connector], new_status)
    |> put_in([:modules, __MODULE__, :state, :connector_statuses_reported_at, connector], DateTime.utc_now())
    |> __MODULE__.Calls.StatusNotification.send(connector, new_status)
  end

  def change_status(_connector, _new_status, state) do
    state
  end

  defp check_status!(0, cp_status) when cp_status in ~w[available unavailable faulted]a, do: :ok

  defp check_status!(_connector, c_status)
       when c_status in ~w[available preparing charging suspended_ev suspended_evse finishing reserved unavailable faulted]a,
       do: :ok

  defp check_status!(connector, status),
    do: raise(ArgumentError, "Unexpected OCPP status for connector #{connector}: #{inspect(status)}")
end
