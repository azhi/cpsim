defmodule CPSIM.CP.Actions.Config do
  defstruct [:initial_queue]

  use Accessible

  @type t :: %__MODULE__{
          initial_queue: CPSIM.CP.Actions.Batch.t()
        }

  def format_response(config) do
    config
    |> Map.from_struct()
  end
end
