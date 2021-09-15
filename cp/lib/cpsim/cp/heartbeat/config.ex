defmodule CPSIM.CP.Heartbeat.Config do
  defstruct [:default_interval]

  use Accessible

  @type t :: %__MODULE__{
          default_interval: non_neg_integer()
        }

  def format_response(config) do
    config
    |> Map.from_struct()
  end
end
