defmodule CPSIM.CP.Connection.Messages.CallResult do
  defstruct [:direction, :id, :payload]

  @type t :: %__MODULE__{
          direction: :incoming | :outgoing,
          id: String.t(),
          payload: String.t()
        }

  @type_id 3
  def type_id, do: @type_id

  def new(%CPSIM.CP.Connection.Messages.Call{direction: :incoming, id: id}, payload) do
    %__MODULE__{direction: :outgoing, id: id, payload: payload}
  end

  def decode([@type_id, id, payload]) do
    %__MODULE__{direction: :incoming, id: id, payload: payload}
  end

  def encode(%__MODULE__{id: id, payload: payload}) do
    [@type_id, id, payload]
  end
end
