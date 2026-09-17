defmodule FlowerShop.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # A fresh webhook signing key per boot; a real shop loads one with
    # Bazaar.Signing.Key.from_pem/1 so its kid stays stable across restarts.
    Application.put_env(:flower_shop, :signing_key, Bazaar.Signing.Key.generate(:p256))

    children = [
      FlowerShop.Store,
      Bazaar.Idempotency.ETS,
      {Task.Supervisor, name: FlowerShop.TaskSupervisor},
      FlowerShopWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: FlowerShop.Supervisor)
  end
end
