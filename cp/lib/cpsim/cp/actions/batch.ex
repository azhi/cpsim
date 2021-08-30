defmodule CPSIM.CP.Actions.Batch do
  @derive {Jason.Encoder, only: [:actions]}
  defstruct [:actions]

  use Accessible

  @type t :: %__MODULE__{
          actions: [CPSIM.CP.Actions.Action.t()]
        }
end
