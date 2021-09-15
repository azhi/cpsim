defmodule CPSIM.CP.Connection.Config do
  defstruct [:soft_reboot_interval, :hard_reboot_interval, :call_timeout_interval, :default_retry_interval]

  use Accessible

  @type t :: %__MODULE__{
          soft_reboot_interval: non_neg_integer(),
          hard_reboot_interval: non_neg_integer(),
          call_timeout_interval: non_neg_integer(),
          default_retry_interval: non_neg_integer()
        }

  def format_response(config) do
    config
    |> Map.from_struct()
  end
end
