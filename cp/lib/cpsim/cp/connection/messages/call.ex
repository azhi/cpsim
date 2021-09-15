defmodule CPSIM.CP.Connection.Messages.Call do
  defstruct [:direction, :sent, :handler, :timeout_timer, :id, :action, :payload]

  @type t :: %__MODULE__{
          direction: :incoming | :outgoing,
          # for outgoing calls - flag whether it was already sent
          sent: boolean() | nil,
          # for outgoing calls - a module responsible for handling call response
          handler: module() | nil,
          # for outgoing calls - a timeout timer ref
          timeout_timer: reference() | nil,
          id: String.t(),
          action: String.t(),
          payload: Map.t()
        }

  @type_id 2
  def type_id, do: @type_id

  def new(action, payload, handler) do
    id = UUID.uuid4()
    %__MODULE__{direction: :outgoing, sent: false, handler: handler, id: id, action: action, payload: payload}
  end

  def decode([@type_id, id, action, payload]) do
    %__MODULE__{direction: :incoming, sent: nil, handler: nil, id: id, action: action, payload: payload}
  end

  def encode(%__MODULE__{id: id, action: action, payload: payload}) do
    [@type_id, id, action, payload]
  end
end
