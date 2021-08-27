defmodule CPSIM.CP.Commands.State do
  defstruct []

  use Accessible

  @type t :: %__MODULE__{}

  def new(_config) do
    %__MODULE__{}
  end
end
