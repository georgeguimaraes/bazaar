defmodule Bazaar.Application do
  @moduledoc false
  # Bazaar's own supervision tree: the task supervisor webhook deliveries run
  # under, and a dynamic supervisor for the ETS-backed stores, which start
  # themselves the first time something reads or writes them. An app that
  # keeps its state elsewhere never starts them.

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Bazaar.TaskSupervisor},
      {DynamicSupervisor, name: Bazaar.DynamicSupervisor, strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Bazaar.Supervisor)
  end

  @doc false
  # Starts a child under bazaar's dynamic supervisor, treating "already
  # running" as success so concurrent first requests race safely.
  def ensure_started(child) do
    case DynamicSupervisor.start_child(Bazaar.DynamicSupervisor, child) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> raise "bazaar could not start #{inspect(child)}: #{inspect(reason)}"
    end
  end
end
