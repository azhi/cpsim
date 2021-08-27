defmodule CPSIM.CP.Actions.Implementations.Authorize do
  alias CPSIM.CP.Actions.Action

  def perform(%Action{type: :authorize, config: config, status: :in_progress} = action, state) do
    state = CPSIM.CP.Actions.Calls.Authorize.send(state, config.id_tag, %{callback: &done/2, action: action})
    {action, state}
  end

  def done(%Action{type: :authorize, status: :in_progress} = action, state) do
    action = %{action | status: :done}
    {action, state}
  end
end
