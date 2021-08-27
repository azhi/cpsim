defmodule CPSIM.CP.Commands.Config do
  defstruct [:supported_commands]

  use Accessible

  @type t :: %__MODULE__{
          supported_commands: [module()]
        }
end
