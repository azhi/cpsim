defmodule CPSIM.CP.Actions.Implementations.StopTransaction do
  alias CPSIM.CP.Actions.Action

  def perform(%Action{type: :stop_transaction, config: config, status: :in_progress} = action, state) do
    state =
      CPSIM.CP.Actions.Calls.StopTransaction.send(state, config.id_tag, %{
        callback: &done/2,
        action: action
      })

    {action, state}
  end

  def done(%Action{type: :stop_transaction, status: :in_progress} = action, state) do
    action = %{action | status: :done}
    {action, state}
  end
end
