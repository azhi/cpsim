defmodule CPSIM.CP.Actions.Implementations.ChargePeriod do
  alias CPSIM.CP.Actions.Action

  @speedup_methods ~w[increase_power time_dilation]a
  def speedup_methods, do: @speedup_methods

  def perform(%Action{type: :charge_period, config: config, status: :in_progress} = action, state) do
    power_offered = Enum.min([config.vehicle_power_capacity, state.internal_config.power_limit])

    action_state = %{
      real_interval: 60,
      speedup_dilated_interval: 60 * maybe_speedup_time(config),
      period_left: config.period,
      vehicle_charge: config.initial_vehicle_charge,
      power: power_offered,
      speedup_increased_power: power_offered * maybe_speedup_power(config),
      power_offered: power_offered
    }

    action = %{action | state: action_state}
    schedule(action)

    {action, state}
  end

  # TODO: simulate approximate physics of charhing an accumulator - drop current and power slowly after reaching 80%
  def update_state_and_send(%Action{type: :charge_period, status: :in_progress} = action, state) do
    charged_by = action.state.speedup_increased_power * action.state.real_interval / 3600.0

    action =
      action
      |> update_in([:state, :period_left], &(&1 - action.state.speedup_dilated_interval))
      |> update_in([:state, :vehicle_charge], &Enum.min([&1 + charged_by, action.config.vehicle_battery_capacity]))

    connector_id = get_in(state, [:modules, CPSIM.CP.Actions, :state, :started_transaction_connector])
    state = update_in(state, [:internal_config, :connector_meters, connector_id], &(&1 + charged_by))

    finished = action.state.period_left <= 0 || action.state.vehicle_charge == action.config.vehicle_battery_capacity

    state =
      if finished do
        # TODO: Transaction.Begin and Transaction.End contexts
        # TODO: Sample.Clock context
        CPSIM.CP.Actions.Calls.MeterValues.send(state, "Sample.Periodic", sampled_values(action, state), %{
          callback: &done/2,
          action: action
        })
      else
        schedule(action)
        CPSIM.CP.Actions.Calls.MeterValues.send(state, "Sample.Periodic", sampled_values(action, state))
      end

    {action, state}
  end

  defp done(%Action{type: :charge_period, status: :in_progress} = action, state) do
    action = %{action | status: :done}
    {action, state}
  end

  defp schedule(action) do
    Process.send_after(
      self(),
      {CPSIM.CP.Actions, :action_callback, %{callback: &update_state_and_send/2, action: action}},
      (action.state.speedup_dilated_interval * 1_000) |> round()
    )
  end

  defp maybe_speedup_power(%{speedup: coeff, speedup_method: :increase_power}), do: coeff
  defp maybe_speedup_power(_), do: 1.0

  defp maybe_speedup_time(%{speedup: coeff, speedup_method: :time_dilation}), do: 1 / coeff
  defp maybe_speedup_time(_), do: 1.0

  defp sampled_values(action, state) do
    connector_id = get_in(state, [:modules, CPSIM.CP.Actions, :state, :started_transaction_connector])

    [
      %{
        value: state.internal_config.connector_meters[connector_id] |> trunc(),
        measurand: "Energy.Active.Import.Register",
        location: "Outlet",
        unit: "Wh"
      },
      %{
        value: action.state.speedup_increased_power,
        measurand: "Power.Active.Import",
        location: "Outlet",
        unit: "W"
      },
      %{
        value: action.state.power_offered,
        measurand: "Power.Offered",
        location: "Outlet",
        unit: "W"
      },
      %{
        value: (action.state.vehicle_charge / action.config.vehicle_battery_capacity * 100) |> trunc(),
        measurand: "SoC",
        location: "EV",
        unit: "%"
      }
    ]
  end
end
