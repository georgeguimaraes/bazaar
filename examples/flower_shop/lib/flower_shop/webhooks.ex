defmodule FlowerShop.Webhooks do
  @moduledoc """
  Order event delivery to the platform.

  The platform's profile (from the `UCP-Agent` header, parsed by
  `Bazaar.Plugs.UCPHeaders`) advertises where order events go, under the
  order capability's `config.webhook_url`. Events are the full order document, delivered in the
  background with `Webhook-Id` and `Webhook-Timestamp` headers, and retried a
  few times on server errors with the exact same body and headers.
  """

  require Logger

  @attempts 3
  @backoff_ms [0, 500, 1_000]

  @doc "Fetches the platform profile and returns its order webhook URL."
  def webhook_url(nil), do: nil

  def webhook_url(profile_url) do
    case Req.get(profile_url, retry: false, receive_timeout: 5_000) do
      {:ok, %{status: 200, body: %{"ucp" => %{"capabilities" => capabilities}}}} ->
        capabilities
        |> Map.get("dev.ucp.shopping.order", [])
        |> Enum.find_value(&get_in(&1, ["config", "webhook_url"]))

      other ->
        Logger.warning("could not read platform profile #{profile_url}: #{inspect(other)}")
        nil
    end
  end

  @doc "Delivers an order event in the background. A missing URL is a no-op."
  def deliver(_event_type, _order, nil), do: :ok

  def deliver(event_type, order, url) do
    body = Jason.encode!(order)
    webhook_id = FlowerShop.Checkout.uuid()

    headers = [
      {"content-type", "application/json"},
      {"webhook-id", webhook_id},
      {"webhook-timestamp", Integer.to_string(System.os_time(:second))},
      {"idempotency-key", webhook_id},
      {"x-event-type", event_type}
    ]

    Task.Supervisor.start_child(FlowerShop.TaskSupervisor, fn -> post(url, body, headers, 1) end)
    :ok
  end

  defp post(url, body, headers, attempt) do
    Process.sleep(Enum.at(@backoff_ms, attempt - 1, 0))

    result = Req.post(url, body: body, headers: headers, retry: false, receive_timeout: 5_000)

    case result do
      {:ok, %{status: status}} when status < 400 ->
        :ok

      {:ok, %{status: status}} when status < 500 ->
        Logger.warning("webhook to #{url} rejected with #{status}, not retrying")

      _ when attempt < @attempts ->
        post(url, body, headers, attempt + 1)

      other ->
        Logger.warning("webhook to #{url} gave up after #{attempt} attempts: #{inspect(other)}")
    end
  end
end
