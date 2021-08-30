defmodule CPSIM.BackendWeb.CPController do
  use CPSIM.BackendWeb, :controller

  def index(conn, _args) do
    cps = CPSIM.CP.list()

    json(conn, cps)
  end

  def show(conn, %{"id" => id}) do
    cp = CPSIM.CP.get_state(id)

    json(conn, cp)
  end

  def create(conn, args) do
    case CPSIM.Backend.Changesets.cp_opts(args) do
      {:ok, opts} ->
        {:ok, _pid} = opts |> Map.to_list() |> CPSIM.CP.launch()
        cp = CPSIM.CP.get_state(opts.internal_config.identity)
        json(conn, cp)

      {:error, cs} ->
        conn
        |> put_status(400)
        # TODO: parseable validation errors
        |> json(%{cs: inspect(cs)})
    end
  end

  def enqueue_action_batch(conn, %{"cp_id" => id} = args) do
    case CPSIM.Backend.Changesets.actions_batch(args) do
      {:ok, batch} ->
        :ok = CPSIM.CP.enqueue_action_batch(id, batch)
        cp = CPSIM.CP.get_state(id)
        json(conn, cp)

      {:error, cs} ->
        conn
        |> put_status(400)
        # TODO: parseable validation errors
        |> json(%{cs: inspect(cs)})
    end
  end

  def delete(conn, %{"id" => id}) do
    :ok = CPSIM.CP.stop(id)
    json(conn, %{status: "ok"})
  end
end
