defmodule CPSIM.BackendWeb.CPChannel do
  use Phoenix.Channel

  def join("cp:" <> identity, _payload, socket) do
    CPSIM.CP.subscribe(identity)
    {:ok, socket}
  end

  def handle_info({:cp_update, _identity, update}, socket) do
    push(socket, :update, update)
    {:noreply, socket}
  end

  def handle_info({:cp_stop, _identity, update}, socket) do
    push(socket, :stop, update)
    {:stop, :normal, socket}
  end
end
