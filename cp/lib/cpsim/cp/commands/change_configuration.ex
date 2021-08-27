defmodule CPSIM.CP.Commands.ChangeConfiguration do
  alias CPSIM.CP.Connection.Messages.{Call, CallResult, CallError}
  alias CPSIM.CP.OCPPConfig

  def handle_call(%Call{payload: %{"key" => key, "value" => value}} = call, state) do
    with :ok <- check_type(:key, key),
         :ok <- check_type(:value, value),
         {:ok, item} <- find_config_item(key, state),
         :ok <- check_item_readonly(item) do
      state = replace_config_value(state, item, value)
      result(call, state, "Accepted")
    else
      {:error, {:wrong_type, field}} ->
        error(call, state, "TypeConstraintViolation", "Expected #{field} to be a string")

      {:error, :unknown_key} ->
        result(call, state, "NotSupported")

      {:error, :readonly} ->
        result(call, state, "Rejected")
    end
  end

  def handle_call(call, state) do
    error(call, state, "PropertyConstraintViolation", "ChangeConfiguration call missing key or value")
  end

  defp check_type(_field, value) when is_binary(value), do: :ok
  defp check_type(field, _value), do: {:error, {:wrong_type, field}}

  defp find_config_item(key, state) do
    item = matching_config_item(key, state)
    if item, do: {:ok, item}, else: {:error, :unknown_key}
  end

  defp matching_config_item(key, state) do
    state.ocpp_config.items
    |> Enum.find(&(&1.key == key))
  end

  defp check_item_readonly(%OCPPConfig.Item{readonly: false}), do: :ok
  defp check_item_readonly(%OCPPConfig.Item{readonly: true}), do: {:error, :readonly}

  defp replace_config_value(state, item, value) do
    item = %{item | value: value}

    update_in(state.ocpp_config.items, fn items -> Enum.map(items, &if(&1.key == item.key, do: item, else: &1)) end)
  end

  defp result(call, state, status) do
    reply =
      CallResult.new(call, %{"status" => status})
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
