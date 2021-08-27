defmodule CPSIM.CP.Connection.State do
  defstruct [:status, :connection_error, :retry_at, :current_time_diff, :outgoing_call_queue, :ws]

  use Accessible

  @type status :: :idle | :ws_init | :boot_notification | :pending | :retry | :done | :resetting

  @type t :: %__MODULE__{
          status: status(),
          connection_error: String.t() | nil,
          retry_at: DateTime.t() | nil,
          # TODO: use this diff
          current_time_diff: non_neg_integer() | nil,
          outgoing_call_queue: [CPSIM.CP.Connection.OutgoingMessage.t()],
          ws: pid() | nil
        }

  def new(_config) do
    %__MODULE__{status: :idle, outgoing_call_queue: []}
  end
end
