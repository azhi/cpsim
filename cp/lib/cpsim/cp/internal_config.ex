defmodule CPSIM.CP.InternalConfig do
  defstruct [:identity, :ws_endpoint, :vendor, :model, :fw_version, :connectors_count, :connector_meters, :power_limit]

  use Accessible

  @type t :: %__MODULE__{
          identity: String.t(),
          ws_endpoint: String.t(),
          vendor: String.t(),
          model: String.t(),
          fw_version: String.t() | nil,
          connectors_count: non_neg_integer(),
          connector_meters: %{non_neg_integer => float()},
          power_limit: non_neg_integer()
        }
end
