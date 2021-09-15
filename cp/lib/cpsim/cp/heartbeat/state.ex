defmodule CPSIM.CP.Heartbeat.State do
  defstruct [:interval, :last_message_at, :last_heartbeat_at]

  use Accessible

  @type t :: %__MODULE__{
          interval: non_neg_integer(),
          last_message_at: DateTime.t() | nil,
          last_heartbeat_at: DateTime.t() | nil
        }

  def new(config) do
    %__MODULE__{interval: config.default_interval}
  end

  def format_response(state) do
    state
    |> Map.from_struct()
    |> Map.take([:interval, :last_message_at, :last_heartbeat_at])
  end
end
