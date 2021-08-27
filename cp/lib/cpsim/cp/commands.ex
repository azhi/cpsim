defmodule CPSIM.CP.Commands do
  alias CPSIM.CP.Connection.Messages.CallError

  def format_response_state(module_state) do
    module_state
    |> Map.from_struct()
  end

  def handle_call(call, state) do
    with {:ok, command_module} <- pick_command_module(call.action),
         :ok <- check_command_enabled(command_module, state) do
      command_module.handle_call(call, state)
    else
      {:error, {:unknown_action, action}} ->
        reply =
          CallError.new(call, "NotImplemented", "Unknown action #{inspect(action)}")
          |> CallError.encode()
          |> Jason.encode!()

        {:reply, reply, state}

      {:error, {:disabled, action}} ->
        reply =
          CallError.new(call, "NotSupported", "Action #{inspect(action)} recognized, but disabled in config")
          |> CallError.encode()
          |> Jason.encode!()

        {:reply, reply, state}
    end
  end

  defp pick_command_module("ChangeConfiguration"), do: {:ok, __MODULE__.ChangeConfiguration}
  defp pick_command_module("GetConfiguration"), do: {:ok, __MODULE__.GetConfiguration}
  defp pick_command_module("Reset"), do: {:ok, __MODULE__.Reset}
  defp pick_command_module("TriggerMessage"), do: {:ok, __MODULE__.TriggerMessage}
  defp pick_command_module(action), do: {:error, {:unknown_action, action}}

  defp check_command_enabled(module, state) do
    if module in state.modules[__MODULE__].config.supported_commands do
      :ok
    else
      {:error, {:disabled, module}}
    end
  end
end
