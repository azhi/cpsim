defmodule CPSIM.CP.Actions.Action do
  @derive {Jason.Encoder, only: [:type, :config, :status, :state]}
  defstruct [:type, :config, :status, :state]

  use Accessible

  @types ~w[status_change authorize start_transaction stop_transaction charge_period delay]a
  def types, do: @types
  @type type :: :status_change | :authorize | :start_transaction | :stop_transaction | :charge_period | :delay

  @statuses ~w[idle in_progress done]a
  def statuses, do: @statuses
  @type status :: :idle | :in_progress | :done

  @type t :: %__MODULE__{
          type: type(),
          config: map(),
          status: status(),
          state: map()
        }

  def new() do
    %__MODULE__{status: :idle, state: %{}}
  end

  def new(type, config) do
    %{new() | type: type, config: config}
  end
end
