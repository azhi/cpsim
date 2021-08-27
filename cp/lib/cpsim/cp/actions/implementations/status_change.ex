defmodule CPSIM.CP.Actions.Implementations.StatusChange do
  alias CPSIM.CP.Actions.Action

  # TODO: fail current batch if change status errored on server side
  def perform(%Action{type: :status_change, config: config, status: :in_progress} = action, state) do
    state = CPSIM.CP.Status.change_status(config.connector, config.status, state)
    action = %{action | status: :done}
    {action, state}
  end
end
