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
          outgoing_call_queue: [CPSIM.CP.Connection.Call.t()],
          ws: pid() | nil
        }

  def new(_config) do
    %__MODULE__{status: :idle, outgoing_call_queue: []}
  end

  def format_response(state) do
    state
    |> Map.from_struct()
    |> Map.take([:status, :connection_error, :retry_at, :current_time_diff, :outgoing_call_queue])
    |> Map.update!(:outgoing_call_queue, fn queue ->
      Enum.map(queue, &CPSIM.CP.Connection.Messages.Call.format_response/1)
    end)
  end
end
