defmodule CPSIM.CP.Status.Config do
  defstruct [:initial_status, :initial_connector_statuses]

  use Accessible

  @type t :: %__MODULE__{
          initial_status: CPSIM.CP.Status.State.ocpp_status(),
          initial_connector_statuses: %{non_neg_integer() => CPSIM.CP.Status.State.ocpp_connector_status()}
        }

  def format_response(config) do
    config
    |> Map.from_struct()
    |> Map.update!(:initial_connector_statuses, &Enum.map(&1, fn {_ind, val} -> val end))
  end
end
