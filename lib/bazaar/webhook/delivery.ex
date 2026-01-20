defmodule Bazaar.Webhook.Delivery do
  @moduledoc """
  Behaviour and default implementation for webhook delivery with retries.

  This module provides:
  1. A behaviour that can be implemented for custom delivery strategies
  2. A default implementation with immediate retries and exponential backoff

  ## Default Implementation

  The default `deliver/5` function sends webhooks immediately and retries
  on failure using exponential backoff. This is suitable for synchronous
  delivery but blocks the calling process during retries.

  ## Custom Delivery Strategies

  For production use, implement this behaviour with your job queue (Oban, etc.):

      defmodule MyApp.AsyncWebhookDelivery do
        @behaviour Bazaar.Webhook.Delivery

        @impl true
        def deliver(order, event_type, url, secret, opts) do
          # Enqueue the webhook for async delivery
          %{order: order, event_type: event_type, url: url, secret: secret}
          |> MyApp.WebhookWorker.new()
          |> Oban.insert()

          {:ok, Bazaar.Webhook.build_event(order, event_type)}
        end
      end

  Then configure your handler or call it directly with your delivery module.

  ## Options

  - `:http_client` - Required HTTP client function `(url, body, headers) -> result`
  - `:max_attempts` - Maximum retry attempts (default: 5)
  - `:base_delay` - Base delay in milliseconds for backoff (default: 1000)
  - `:max_delay` - Maximum delay cap in milliseconds (default: 30000)
  """

  alias Bazaar.Webhook
  alias Bazaar.Webhook.Retry

  @type order :: map()
  @type event_type :: atom()
  @type url :: String.t()
  @type secret :: String.t()
  @type opts :: keyword()
  @type event :: map()

  @doc """
  Delivers a webhook event for the given order.

  Should return `{:ok, event}` on success or `{:error, reason}` on failure.
  """
  @callback deliver(order(), event_type(), url(), secret(), opts()) ::
              {:ok, event()} | {:error, term()}

  @doc """
  Delivers a webhook with automatic retries using exponential backoff.

  This is a synchronous implementation that blocks during retries.
  For async delivery, implement the behaviour with your job queue.

  ## Options

  - `:http_client` - Required. Function `(url, body, headers) -> {:ok, %{status, body}} | {:error, reason}`
  - `:max_attempts` - Maximum attempts including first try (default: 5)
  - `:base_delay` - Base delay in ms for exponential backoff (default: 1000)
  - `:max_delay` - Maximum delay cap in ms (default: 30000)

  ## Returns

  - `{:ok, event}` - Event was delivered successfully
  - `{:error, {:max_attempts_reached, attempts, last_error}}` - All retries exhausted
  - `{:error, reason}` - Non-retryable error on first attempt

  ## Example

      http_client = fn url, body, headers ->
        Req.post(url, body: body, headers: headers)
        |> case do
          {:ok, %{status: status, body: body}} -> {:ok, %{status: status, body: body}}
          {:error, reason} -> {:error, reason}
        end
      end

      Delivery.deliver(order, :order_created, url, secret,
        http_client: http_client,
        max_attempts: 5,
        base_delay: 1000
      )
  """
  def deliver(order, event_type, webhook_url, webhook_secret, opts \\ []) do
    http_client = Keyword.fetch!(opts, :http_client)
    max_attempts = Keyword.get(opts, :max_attempts, 5)
    retry_opts = Keyword.take(opts, [:base_delay, :max_delay])

    do_deliver(
      order,
      event_type,
      webhook_url,
      webhook_secret,
      http_client,
      1,
      max_attempts,
      retry_opts,
      nil
    )
  end

  defp do_deliver(
         order,
         event_type,
         url,
         secret,
         http_client,
         attempt,
         max_attempts,
         retry_opts,
         _last_error
       )
       when attempt <= max_attempts do
    case Webhook.send(order, event_type, url, secret, http_client: http_client) do
      {:ok, event} ->
        {:ok, event}

      {:error, error} ->
        cond do
          # Non-retryable error - return immediately
          not Retry.retryable_error?(error) ->
            {:error, error}

          # Retryable error but we've hit max attempts
          attempt >= max_attempts ->
            {:error, {:max_attempts_reached, attempt, error}}

          # Retryable error with attempts remaining - retry
          true ->
            delay = Retry.calculate_delay(attempt, retry_opts)
            Process.sleep(delay)

            do_deliver(
              order,
              event_type,
              url,
              secret,
              http_client,
              attempt + 1,
              max_attempts,
              retry_opts,
              error
            )
        end
    end
  end

  defp do_deliver(
         _order,
         _event_type,
         _url,
         _secret,
         _http_client,
         attempt,
         _max_attempts,
         _retry_opts,
         last_error
       ) do
    {:error, {:max_attempts_reached, attempt - 1, last_error}}
  end
end
