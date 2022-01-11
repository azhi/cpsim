defmodule CPSIM.CP do
  import CPSIM.CP.DynamicSupervisor, only: [via: 1]

  defdelegate launch(opts), to: CPSIM.CP.DynamicSupervisor
  defdelegate list(), to: CPSIM.CP.DynamicSupervisor

  defdelegate start_link(opts), to: CPSIM.CP.Core
  defdelegate child_spec(opts), to: CPSIM.CP.Core

  def subscribe(identity), do: via(identity) |> CPSIM.CP.Core.add_subscriber()
  def stop(identity, reason \\ :normal), do: via(identity) |> CPSIM.CP.Core.stop(reason)

  def enqueue_action_batch(identity, action_batch),
    do: via(identity) |> CPSIM.CP.Actions.enqueue_action_batch(action_batch)

  def get_state(identity), do: via(identity) |> CPSIM.CP.Core.get_state()
end
