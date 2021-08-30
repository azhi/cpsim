defmodule CPSIM.CP.Status.State do
  defstruct [:status, :status_reported_at, :connector_statuses, :connector_statuses_reported_at]

  @ocpp_statuses ~w[available unavailable faulted]a
  def ocpp_statuses, do: @ocpp_statuses
  @type ocpp_status :: :available | :unavailable | :faulted

  @ocpp_connector_statuses ~w[available preparing charging suspended_ev suspended_evse finishing reserved unavailable faulted]a
  def ocpp_connector_statuses, do: @ocpp_connector_statuses

  @type ocpp_connector_status ::
          :available
          | :preparing
          | :charging
          | :suspended_ev
          | :suspended_evse
          | :finishing
          | :reserved
          | :unavailable
          | :faulted

  use Accessible

  @type t :: %__MODULE__{
          status: ocpp_status(),
          status_reported_at: DateTime.t() | nil,
          connector_statuses: %{non_neg_integer() => ocpp_connector_status},
          connector_statuses_reported_at: %{non_neg_integer() => DateTime.t() | nil}
        }

  def new(config) do
    %__MODULE__{
      status: config.initial_status,
      connector_statuses: config.initial_connector_statuses,
      connector_statuses_reported_at:
        Enum.map(config.initial_connector_statuses, fn {c, _s} -> {c, nil} end) |> Enum.into(%{})
    }
  end
end
