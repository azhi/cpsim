defmodule CPSIM.CP.Actions.Action do
  defstruct [:type, :config, :status, :state]

  use Accessible

  @type type :: :status_change | :authorize | :start_transaction | :stop_transaction | :charge_period | :delay
  @type status :: :idle | :in_progress | :done

  @type t :: %__MODULE__{
          type: type(),
          config: map(),
          status: status(),
          state: map()
        }

  def new(type, config) do
    %__MODULE__{type: type, config: config, status: :idle, state: %{}}
  end
end
