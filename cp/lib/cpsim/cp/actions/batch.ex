defmodule CPSIM.CP.Actions.Batch do
  defstruct [:actions]

  use Accessible

  @type t :: %__MODULE__{
          actions: [CPSIM.CP.Actions.Action.t()]
        }
end
