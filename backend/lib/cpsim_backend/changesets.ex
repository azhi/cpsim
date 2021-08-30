defmodule CPSIM.Backend.Changesets do
  alias CPSIM.CP.{InternalConfig, OCPPConfig, Connection, Actions, Heartbeat, Commands, Status}

  def cp_opts(args) do
    types = %{internal_config: :map, ocpp_config: {:array, :map}, modules: :map}

    with {:ok, args} <-
           {%{}, types}
           |> Ecto.Changeset.cast(args, Map.keys(types))
           |> Ecto.Changeset.validate_required(Map.keys(types))
           |> Ecto.Changeset.apply_action(:validate),
         {:ok, args} <- cast_embed(args, [:internal_config], &internal_config/1),
         {:ok, args} <- cast_embeds(args, [:ocpp_config], &ocpp_config/1),
         {:ok, args} <- cast_embed(args, [:modules], &modules/1) do
      args
      |> update_in([:ocpp_config], &%OCPPConfig{items: &1})
      |> then(&{:ok, &1})
    end
  end

  defp cast_embed(args, path, func) do
    value = get_in(args, path)

    if value do
      with {:ok, value} <- func.(value) do
        {:ok, put_in(args, path, value)}
      end
    else
      {:ok, args}
    end
  end

  defp cast_embeds(args, path, func) do
    values = get_in(args, path)

    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case func.(value) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, put_in(args, path, Enum.reverse(values))}
      {:error, reason} -> {:error, reason}
    end
  end

  defp internal_config(args) do
    types = %{
      identity: :string,
      ws_endpoint: :string,
      vendor: :string,
      model: :string,
      fw_version: :string,
      connectors_count: :integer,
      connector_meters: {:array, :float},
      power_limit: :integer
    }

    {%InternalConfig{}, types}
    |> Ecto.Changeset.cast(args, Map.keys(types))
    |> Ecto.Changeset.validate_required(
      ~w[identity ws_endpoint vendor model connectors_count connector_meters power_limit]a
    )
    |> Ecto.Changeset.validate_number(:connectors_count, greater_than: 0)
    |> Ecto.Changeset.validate_number(:power_limit, greater_than: 0)
    |> then(
      &Ecto.Changeset.validate_change(&1, :connector_meters, fn _key, meter ->
        count = Ecto.Changeset.get_field(&1, :connectors_count)

        if length(meter) == count do
          []
        else
          [connector_meters: "should have connectors_count (#{count}) elements"]
        end
      end)
    )
    |> Ecto.Changeset.update_change(:connector_meters, fn meters ->
      Enum.with_index(meters, 1)
      |> Enum.map(fn {value, ind} -> {ind, value} end)
      |> Enum.into(%{})
    end)
    |> Ecto.Changeset.apply_action(:validate)
  end

  defp ocpp_config(args) do
    types = %{key: :string, value: :string, readonly: :boolean}

    {%OCPPConfig.Item{}, types}
    |> Ecto.Changeset.cast(args, Map.keys(types))
    |> Ecto.Changeset.validate_required(~w[key readonly]a)
    |> Ecto.Changeset.apply_action(:validate)
  end

  defp modules(args) do
    types = %{connection: :map, actions: :map, heartbeat: :map, commands: :map, status: :map}

    with {:ok, args} <-
           {%{}, types}
           |> Ecto.Changeset.cast(args, Map.keys(types))
           |> Ecto.Changeset.validate_required(~w[connection status]a)
           |> Ecto.Changeset.apply_action(:validate),
         {:ok, args} <- cast_embed(args, [:connection], &connection_module/1),
         {:ok, args} <- cast_embed(args, [:actions], &actions_module/1),
         {:ok, args} <- cast_embed(args, [:heartbeat], &heartbeat_module/1),
         {:ok, args} <- cast_embed(args, [:commands], &commands_module/1),
         {:ok, args} <- cast_embed(args, [:status], &status_module/1) do
      args
      |> Enum.map(fn {module_name, module_config} ->
        {module_from_name(module_name), module_config}
      end)
      |> Enum.into(%{})
      |> then(&{:ok, &1})
    end
  end

  defp module_from_name(:connection), do: Connection
  defp module_from_name(:actions), do: Actions
  defp module_from_name(:heartbeat), do: Heartbeat
  defp module_from_name(:commands), do: Commands
  defp module_from_name(:status), do: Status

  defp connection_module(args) do
    types = %{
      soft_reboot_interval: :integer,
      hard_reboot_interval: :integer,
      call_timeout_interval: :integer,
      default_retry_interval: :integer
    }

    {%Connection.Config{}, types}
    |> Ecto.Changeset.cast(args, Map.keys(types))
    |> Ecto.Changeset.validate_required(Map.keys(types))
    |> then(
      &Enum.reduce(Map.keys(types), &1, fn key, cs ->
        Ecto.Changeset.validate_number(cs, key, greater_than: 0)
      end)
    )
    |> Ecto.Changeset.apply_action(:validate)
  end

  defp actions_module(args) do
    types = %{initial_queue: {:array, :map}}

    with {:ok, args} <-
           {%Actions.Config{}, types}
           |> Ecto.Changeset.cast(args, Map.keys(types))
           |> Ecto.Changeset.validate_required(Map.keys(types))
           |> Ecto.Changeset.apply_action(:validate),
         {:ok, args} <- cast_embeds(args, [:initial_queue], &actions_batch/1) do
      {:ok, args}
    end
  end

  def actions_batch(args) do
    types = %{actions: {:array, :map}}

    with {:ok, args} <-
           {%Actions.Batch{}, types}
           |> Ecto.Changeset.cast(args, Map.keys(types))
           |> Ecto.Changeset.validate_required(Map.keys(types))
           |> Ecto.Changeset.validate_length(:actions, min: 1)
           |> Ecto.Changeset.apply_action(:validate),
         {:ok, args} <- cast_embeds(args, [:actions], &actions_batch_action/1) do
      {:ok, args}
    end
  end

  defp actions_batch_action(args) do
    types = %{type: :string, config: :map}

    with {:ok, args} <-
           {Actions.Action.new(), types}
           |> Ecto.Changeset.cast(args, Map.keys(types))
           |> Ecto.Changeset.validate_required(Map.keys(types))
           |> Ecto.Changeset.validate_inclusion(
             :type,
             Actions.Action.types() |> Enum.map(&to_string/1)
           )
           |> Ecto.Changeset.update_change(:type, &String.to_atom/1)
           |> Ecto.Changeset.apply_action(:validate),
         {:ok, args} <- cast_embed(args, [:config], &actions_parse_config(args.type, &1)) do
      {:ok, args}
    end
  end

  defp actions_parse_config(:status_change, args) do
    types = %{connector: :integer, status: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(args, Map.keys(types))
    |> Ecto.Changeset.validate_required(Map.keys(types))
    |> Ecto.Changeset.validate_number(:connector, greater_than_or_equal_to: 0)
    |> Ecto.Changeset.validate_inclusion(
      :status,
      CPSIM.CP.Status.State.ocpp_connector_statuses() |> Enum.map(&to_string/1)
    )
    |> Ecto.Changeset.update_change(:status, &String.to_atom/1)
    |> Ecto.Changeset.apply_action(:validate)
  end

  defp actions_parse_config(:authorize, args) do
    types = %{id_tag: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(args, Map.keys(types))
    |> Ecto.Changeset.validate_required(Map.keys(types))
    |> Ecto.Changeset.validate_length(:id_tag, min: 1)
    |> Ecto.Changeset.apply_action(:validate)
  end

  defp actions_parse_config(:start_transaction, args) do
    types = %{connector: :integer, id_tag: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(args, Map.keys(types))
    |> Ecto.Changeset.validate_required(Map.keys(types))
    |> Ecto.Changeset.validate_number(:connector, greater_than: 0)
    |> Ecto.Changeset.validate_length(:id_tag, min: 1)
    |> Ecto.Changeset.apply_action(:validate)
  end

  defp actions_parse_config(:stop_transaction, args) do
    types = %{id_tag: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(args, Map.keys(types))
    |> Ecto.Changeset.validate_required(Map.keys(types))
    |> Ecto.Changeset.validate_length(:id_tag, min: 1)
    |> Ecto.Changeset.apply_action(:validate)
  end

  defp actions_parse_config(:charge_period, args) do
    types = %{
      vehicle_power_capacity: :integer,
      initial_vehicle_charge: :integer,
      period: :integer,
      vehicle_battery_capacity: :integer,
      speedup: :float,
      speedup_method: :string
    }

    {%{}, types}
    |> Ecto.Changeset.cast(args, Map.keys(types))
    |> Ecto.Changeset.validate_required(
      ~w[vehicle_power_capacity initial_vehicle_charge period vehicle_battery_capacity]a
    )
    |> Ecto.Changeset.validate_number(:vehicle_power_capacity, greater_than: 0)
    |> Ecto.Changeset.validate_number(:initial_vehicle_charge, greater_than: 0)
    |> Ecto.Changeset.validate_number(:period, greater_than: 0)
    |> Ecto.Changeset.validate_number(:vehicle_battery_capacity, greater_than: 0)
    |> Ecto.Changeset.validate_number(:speedup, greater_than: 0.0)
    |> Ecto.Changeset.validate_inclusion(
      :speedup_method,
      CPSIM.CP.Actions.Implementations.ChargePeriod.speedup_methods() |> Enum.map(&to_string/1)
    )
    |> Ecto.Changeset.update_change(:speedup_method, &String.to_atom/1)
    |> Ecto.Changeset.apply_action(:validate)
  end

  defp actions_parse_config(:delay, args) do
    types = %{interval: :integer}

    {%{}, types}
    |> Ecto.Changeset.cast(args, Map.keys(types))
    |> Ecto.Changeset.validate_required(Map.keys(types))
    |> Ecto.Changeset.validate_number(:interval, greater_than: 0)
    |> Ecto.Changeset.apply_action(:validate)
  end

  defp heartbeat_module(args) do
    types = %{default_interval: :integer}

    {%Heartbeat.Config{}, types}
    |> Ecto.Changeset.cast(args, Map.keys(types))
    |> Ecto.Changeset.validate_required(Map.keys(types))
    |> Ecto.Changeset.validate_number(:default_interval, greater_than: 0)
    |> Ecto.Changeset.apply_action(:validate)
  end

  defp commands_module(args) do
    types = %{supported_commands: {:array, :string}}

    {%Commands.Config{}, types}
    |> Ecto.Changeset.cast(args, Map.keys(types))
    |> Ecto.Changeset.validate_required(Map.keys(types))
    |> Ecto.Changeset.validate_subset(
      :supported_commands,
      ~w[change_configuration get_configuration reset trigger_message]
    )
    |> Ecto.Changeset.update_change(:supported_commands, fn sc ->
      Enum.map(sc, &command_module_from_name/1)
    end)
    |> Ecto.Changeset.apply_action(:validate)
  end

  defp command_module_from_name("change_configuration"), do: Commands.ChangeConfiguration
  defp command_module_from_name("get_configuration"), do: Commands.GetConfiguration
  defp command_module_from_name("reset"), do: Commands.Reset
  defp command_module_from_name("trigger_message"), do: Commands.TriggerMessage

  defp status_module(args) do
    types = %{initial_status: :string, initial_connector_statuses: {:array, :string}}

    {%Status.Config{}, types}
    |> Ecto.Changeset.cast(args, Map.keys(types))
    |> Ecto.Changeset.validate_required(Map.keys(types))
    |> Ecto.Changeset.validate_inclusion(
      :initial_status,
      CPSIM.CP.Status.State.ocpp_statuses() |> Enum.map(&to_string/1)
    )
    |> Ecto.Changeset.validate_subset(
      :initial_connector_statuses,
      CPSIM.CP.Status.State.ocpp_connector_statuses() |> Enum.map(&to_string/1)
    )
    |> Ecto.Changeset.update_change(:initial_status, &String.to_atom/1)
    |> Ecto.Changeset.update_change(:initial_connector_statuses, fn statuses ->
      statuses
      |> Enum.map(&String.to_atom/1)
      |> Enum.with_index(1)
      |> Enum.map(fn {value, ind} -> {ind, value} end)
      |> Enum.into(%{})
    end)
    |> Ecto.Changeset.apply_action(:validate)
  end
end
