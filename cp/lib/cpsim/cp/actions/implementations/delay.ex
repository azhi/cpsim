defmodule CPSIM.CP.Actions.Implementations.Delay do
  alias CPSIM.CP.Actions.Action

  def perform(%Action{type: :delay, config: config, status: :in_progress} = action, state) do
    Process.send_after(
      self(),
      {CPSIM.CP.Actions, :action_callback, %{callback: &done/2, action: action}},
      config.interval * 1_000
    )

    {action, state}
  end

  def done(%Action{type: :delay, status: :in_progress} = action, state) do
    action = %{action | status: :done}
    {action, state}
  end
end
