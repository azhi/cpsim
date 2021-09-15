defmodule CPSIM.CP.Commands.Config do
  defstruct [:supported_commands]

  use Accessible

  @type t :: %__MODULE__{
          supported_commands: [module()]
        }

  def format_response(config) do
    config
    |> Map.from_struct()
  end
end
