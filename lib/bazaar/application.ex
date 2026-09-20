defmodule Bazaar.Application do
  @moduledoc false
  # Bazaar's own supervision tree: the task supervisor webhook deliveries
  # run under, so an app needs nothing of its own for them.

  use Application

  @impl true
  def start(_type, _args) do
    children = [{Task.Supervisor, name: Bazaar.TaskSupervisor}]
    Supervisor.start_link(children, strategy: :one_for_one, name: Bazaar.Supervisor)
  end
end
