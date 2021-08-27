defmodule CPSIM.CP.Commands.GetConfiguration do
  alias CPSIM.CP.Connection.Messages.{Call, CallResult, CallError}

  def handle_call(%Call{payload: payload} = call, state) do
    with :ok <- check_keys(payload),
         {items, not_found} <- find_config_items(payload, state) do
      result(call, state, items, not_found)
    else
      {:error, {:wrong_type, :list}} ->
        error(call, state, "TypeConstraintViolation", "Expected key to be a list")

      {:error, {:wrong_type, :list_element}} ->
        error(call, state, "TypeConstraintViolation", "Expected all key list to be a strings")
    end
  end

  defp check_keys(%{"key" => keys}) when is_list(keys) do
    if Enum.all?(keys, &is_binary/1) do
      :ok
    else
      {:error, {:wrong_type, :list_element}}
    end
  end

  defp check_keys(%{"key" => _keys}) do
    {:error, {:wrong_type, :list}}
  end

  defp check_keys(_payload) do
    :ok
  end

  defp find_config_items(%{"key" => keys}, state) do
    {existing, not_found} = Enum.split_with(keys, &matching_config_item(&1, state))
    items = Enum.map(existing, &matching_config_item(&1, state))
    {items, not_found}
  end

  defp find_config_items(_payload, state) do
    {state.ocpp_config.items, []}
  end

  defp matching_config_item(key, state) do
    state.ocpp_config.items
    |> Enum.find(&(&1.key == key))
  end

  defp result(call, state, items, not_found) do
    payload = %{"configurationKey" => items}
    payload = if not_found != [], do: Map.put(payload, "unknownKey", not_found), else: payload

    reply =
      CallResult.new(call, payload)
      |> CallResult.encode()
      |> Jason.encode!()

    {{:reply, reply}, state}
  end

  defp error(call, state, code, desc, details \\ %{}) do
    reply =
      CallError.new(call, code, desc, details)
      |> CallError.encode()
      |> Jason.encode!()

    {{:reply, reply}, state}
  end
end
