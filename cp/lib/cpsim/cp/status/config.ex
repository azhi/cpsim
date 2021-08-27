defmodule CPSIM.CP.Status.Config do
  defstruct [:initial_status, :initial_connector_statuses]

  use Accessible

  @type t :: %__MODULE__{
          initial_status: CPSIM.CP.Status.State.ocpp_status(),
          initial_connector_statuses: %{non_neg_integer() => CPSIM.CP.Status.State.ocpp_connector_status()}
        }
end
