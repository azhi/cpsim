defmodule CPSIM.CP.Actions.State do
  # TODO: add manual commands in status = idle mode
  defstruct [
    :status,
    :queue,
    :instruction_pointer,
    :action_callback,
    :started_transaction_id,
    :started_transaction_connector
  ]

  use Accessible

  @type t :: %__MODULE__{
          status: :idle | :executing,
          queue: [CPSIM.CP.Actions.Batch.t()],
          instruction_pointer: {non_neg_integer(), non_neg_integer()},
          action_callback:
            %{
              callback: (CPSIM.CP.Actions.Action.t(), any() -> any()),
              action: CPSIM.CP.Actions.Action.t()
            }
            | nil,
          # FIXME: a hack
          started_transaction_id: non_neg_integer() | nil,
          started_transaction_connector: non_neg_integer() | nil
        }

  def new(config) do
    case config.initial_queue do
      list when is_list(list) and length(list) > 0 ->
        %__MODULE__{status: :executing, queue: config.initial_queue, instruction_pointer: {0, 0}}

      _else ->
        %__MODULE__{status: :idle, queue: [], instruction_pointer: {nil, nil}}
    end
  end
end
