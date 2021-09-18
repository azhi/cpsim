defmodule CPSIM.CP.OCPPConfig do
  defmodule Item do
    @derive Jason.Encoder
    defstruct [:key, :value, :readonly]

    use Accessible

    @type t :: %__MODULE__{
            key: String.t(),
            value: String.t() | nil,
            readonly: boolean()
          }
  end

  defstruct [:items]

  # TODO: add read helpers here, implement all OCPP standard config items

  use Accessible

  @type t :: %__MODULE__{items: [Item.t()]}
end
