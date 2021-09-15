defmodule CPSIM.CP.Actions do
  alias __MODULE__.{Action, Batch}

  defguardp enabled?(state) when is_map_key(state.modules, __MODULE__)

  def enqueue_action_batch(name, %Batch{actions: actions} = action_batch)
      when is_list(actions) and length(actions) > 0 do
    GenServer.call(name, {__MODULE__, :enqueue_action_batch, action_batch})
  end

  def enqueue_action_batch(_name, _action_batch) do
    {:error, :invalid_batch}
  end

  def active_transaction?(state) do
    !!get_in(state, [:modules, __MODULE__, :state, :started_transaction_id])
  end

  def init(state) when enabled?(state) do
    perform_if_needed(state)
  end

  def init(state) do
    state
  end

  def handle_info({:action_callback, action_callback}, state) do
    {:noreply, call_action_callback(state, action_callback)}
  end

  def handle_call({:enqueue_action_batch, action_batch}, _from, state) when enabled?(state) do
    state =
      state
      |> update_in([:modules, __MODULE__, :state, :queue], &(&1 ++ [action_batch]))
      |> put_in([:modules, __MODULE__, :state, :status], :executing)
      |> update_in([:modules, __MODULE__, :state, :instruction_pointer], fn
        {nil, nil} -> {0, 0}
        existing -> existing
      end)
      |> perform_if_needed()

    {:reply, :ok, state}
  end

  def handle_call(_, state) do
    {:reply, {:error, :disabled}, state}
  end

  def call_action_callback(state, %{callback: callback_fn, action: action}) do
    {action, state} = apply(callback_fn, [action, state])

    update_current_instruction(state, action)
    |> perform_if_needed()
  end

  # TODO: mark batch as failed with explanation
  def skip_current_batch(state) do
    step_current_instruction(state, :batch)
  end

  defp perform_if_needed(state) do
    case current_instruction(state) do
      %Action{status: :idle} = action ->
        # perform new action
        action = %{action | status: :in_progress}
        {action, state} = action_implementation(action).perform(action, state)

        update_current_instruction(state, action)
        |> perform_if_needed()

      %Action{status: :in_progress} ->
        # already in progress, nothing to do
        state

      %Action{status: :done} ->
        # step into next instruction
        step_current_instruction(state)
        |> perform_if_needed()

      nil ->
        # no instructions, nothing to do
        state
    end
  end

  defp current_instruction(state) do
    case get_in(state, [:modules, __MODULE__, :state, :instruction_pointer]) do
      {nil, nil} ->
        nil

      {batch_ind, action_ind} ->
        get_in(state, [:modules, __MODULE__, :state, :queue])
        |> Enum.at(batch_ind)
        |> then(& &1.actions)
        |> Enum.at(action_ind)
    end
  end

  defp update_current_instruction(state, action) do
    {batch_ind, action_ind} = get_in(state, [:modules, __MODULE__, :state, :instruction_pointer])

    update_in(state, [:modules, __MODULE__, :state, :queue], fn queue ->
      List.update_at(queue, batch_ind, fn batch ->
        %{batch | actions: List.replace_at(batch.actions, action_ind, action)}
      end)
    end)
  end

  defp step_current_instruction(state, step \\ :instruction) do
    {batch_ind, action_ind} = get_in(state, [:modules, __MODULE__, :state, :instruction_pointer])
    queue = get_in(state, [:modules, __MODULE__, :state, :queue])
    batch = Enum.at(queue, batch_ind)

    cond do
      step == :instruction && action_ind + 1 < length(batch.actions) ->
        put_in(state, [:modules, __MODULE__, :state, :instruction_pointer], {batch_ind, action_ind + 1})

      step in [:instruction, :batch] && batch_ind + 1 < length(queue) ->
        put_in(state, [:modules, __MODULE__, :state, :instruction_pointer], {batch_ind + 1, 0})

      true ->
        state
        |> put_in([:modules, __MODULE__, :state, :instruction_pointer], {nil, nil})
        |> put_in([:modules, __MODULE__, :state, :status], :idle)
    end
  end

  defp action_implementation(%Action{type: :status_change}), do: __MODULE__.Implementations.StatusChange
  defp action_implementation(%Action{type: :authorize}), do: __MODULE__.Implementations.Authorize
  defp action_implementation(%Action{type: :start_transaction}), do: __MODULE__.Implementations.StartTransaction
  defp action_implementation(%Action{type: :charge_period}), do: __MODULE__.Implementations.ChargePeriod
  defp action_implementation(%Action{type: :stop_transaction}), do: __MODULE__.Implementations.StopTransaction
  defp action_implementation(%Action{type: :delay}), do: __MODULE__.Implementations.Delay
end
