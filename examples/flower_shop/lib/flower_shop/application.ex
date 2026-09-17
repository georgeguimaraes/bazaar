defmodule FlowerShop.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FlowerShop.Store,
      {Task.Supervisor, name: FlowerShop.TaskSupervisor},
      FlowerShopWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: FlowerShop.Supervisor)
  end
end
