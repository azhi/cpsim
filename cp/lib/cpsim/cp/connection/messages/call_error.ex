defmodule CPSIM.CP.Connection.Messages.CallError do
  defstruct [:direction, :id, :error_code, :error_desc, :error_details]

  @type t :: %__MODULE__{
          direction: :incoming | :outgoing,
          id: String.t(),
          error_code: String.t(),
          error_desc: String.t(),
          error_details: Map.t()
        }

  @type_id 4
  def type_id, do: @type_id

  def new(%CPSIM.CP.Connection.Messages.Call{direction: :incoming, id: id}, code, desc \\ "", details \\ %{}) do
    %__MODULE__{direction: :outgoing, id: id, error_code: code, error_desc: desc, error_details: details}
  end

  def decode([@type_id, id, code, desc, details]) do
    %__MODULE__{direction: :incoming, id: id, error_code: code, error_desc: desc, error_details: details}
  end

  def encode(%__MODULE__{id: id, error_code: code, error_desc: desc, error_details: details}) do
    [@type_id, id, code, desc, details]
  end
end
