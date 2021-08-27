defmodule CPSIM.CP.Connection.Messages do
  def decode(json_str) do
    case Jason.decode(json_str) do
      {:ok, json_data} when is_list(json_data) ->
        type_id = List.first(json_data)
        decode_data_by_type_id(type_id, json_data)

      {:ok, other} ->
        {:error, {:unexpected_json, other}}

      {:error, decode_error} ->
        {:error, decode_error}
    end
  end

  defp decode_data_by_type_id(type_id, json_data) do
    [__MODULE__.Call, __MODULE__.CallError, __MODULE__.CallResult]
    |> Enum.find(fn decoder -> decoder.type_id == type_id end)
    |> then(&decode_with_decoder(&1, json_data))
  end

  defp decode_with_decoder(module, json_data) when is_atom(module) do
    {:ok, module.decode(json_data)}
  end

  defp decode_with_decoder(nil, json_data) do
    {:error, {:unknown_type_id, json_data}}
  end
end
