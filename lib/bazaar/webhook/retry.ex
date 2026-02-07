defmodule Bazaar.Webhook.Retry do
  @moduledoc """
  Retry helpers for webhook delivery.

  This module provides pure functions for calculating retry delays and determining
  whether to retry failed webhook deliveries. It does NOT include any process
  management - users should integrate with their own job queue (Oban, etc.).

  ## Exponential Backoff

  Delays are calculated using exponential backoff: `base_delay * 2^(attempt - 1)`

  Default schedule with 5 attempts:
  - Attempt 1: 0ms (immediate)
  - Attempt 2: 1s delay
  - Attempt 3: 2s delay
  - Attempt 4: 4s delay
  - Attempt 5: 8s delay

  ## Retryable Errors

  By default, these errors are considered retryable:
  - HTTP 5xx (server errors)
  - HTTP 429 (rate limited)
  - Network errors (`:timeout`, `:econnrefused`, etc.)

  HTTP 4xx errors (except 429) are NOT retried as they indicate client errors
  that won't be resolved by retrying.

  ## Usage with Oban

      defmodule MyApp.WebhookWorker do
        use Oban.Worker

        alias Bazaar.Webhook
        alias Bazaar.Webhook.Retry

        @impl Oban.Worker
        def perform(%{args: args, attempt: attempt}) do
          result = Webhook.send(order, event_type, url, secret, http_client: &http_post/3)

          case result do
            {:ok, _} ->
              :ok

            {:error, error} ->
              if Retry.should_retry?(attempt, max_attempts: 5, error: error) do
                delay = Retry.calculate_delay(attempt)
                {:snooze, div(delay, 1000)}
              else
                {:discard, "Non-retryable error: \#{inspect(error)}"}
              end
          end
        end
      end
  """

  @default_base_delay 1000
  @default_max_delay 30_000
  @default_max_attempts 5
  @default_jitter 0.0

  @doc """
  Calculates the delay in milliseconds for a given attempt number.

  Uses exponential backoff: `base_delay * 2^(attempt - 1)`

  ## Options

  - `:base_delay` - Base delay in milliseconds (default: 1000)
  - `:max_delay` - Maximum delay cap in milliseconds (default: 30000)

  ## Examples

      iex> Retry.calculate_delay(1, base_delay: 1000)
      1000

      iex> Retry.calculate_delay(3, base_delay: 1000)
      4000

      iex> Retry.calculate_delay(10, base_delay: 1000, max_delay: 5000)
      5000
  """
  def calculate_delay(attempt, opts \\ []) do
    base_delay = Keyword.get(opts, :base_delay, @default_base_delay)
    max_delay = Keyword.get(opts, :max_delay, @default_max_delay)

    delay = base_delay * Integer.pow(2, attempt - 1)
    min(delay, max_delay)
  end

  @doc """
  Calculates delay with random jitter to prevent thundering herd.

  Jitter is applied as a percentage deviation from the calculated delay.

  ## Options

  - `:base_delay` - Base delay in milliseconds (default: 1000)
  - `:max_delay` - Maximum delay cap (default: 30000)
  - `:jitter` - Jitter percentage as float 0.0-1.0 (default: 0.0)

  ## Examples

      iex> delay = Retry.calculate_delay_with_jitter(1, base_delay: 1000, jitter: 0.1)
      iex> delay >= 900 and delay <= 1100
      true
  """
  def calculate_delay_with_jitter(attempt, opts \\ []) do
    jitter = Keyword.get(opts, :jitter, @default_jitter)
    base = calculate_delay(attempt, opts)

    if jitter > 0 do
      variance = trunc(base * jitter)
      base - variance + :rand.uniform(variance * 2 + 1) - 1
    else
      base
    end
  end

  @doc """
  Determines whether a failed attempt should be retried.

  Returns `false` if:
  - Attempt number >= max_attempts
  - Error is not retryable (e.g., HTTP 4xx except 429)

  ## Options

  - `:max_attempts` - Maximum number of attempts (default: 5)
  - `:error` - The error to check for retryability (required)

  ## Examples

      iex> Retry.should_retry?(1, max_attempts: 3, error: :timeout)
      true

      iex> Retry.should_retry?(3, max_attempts: 3, error: :timeout)
      false

      iex> Retry.should_retry?(1, max_attempts: 3, error: {:http_error, 400, ""})
      false
  """
  def should_retry?(attempt, opts) do
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    error = Keyword.fetch!(opts, :error)

    attempt < max_attempts and retryable_error?(error)
  end

  @doc """
  Checks if an error is retryable.

  Retryable errors:
  - HTTP 5xx (server errors)
  - HTTP 429 (rate limited)
  - Network errors (`:timeout`, `:econnrefused`, `:closed`, etc.)

  Non-retryable errors:
  - HTTP 4xx (except 429) - client errors

  ## Examples

      iex> Retry.retryable_error?({:http_error, 500, ""})
      true

      iex> Retry.retryable_error?({:http_error, 400, ""})
      false

      iex> Retry.retryable_error?(:timeout)
      true
  """
  def retryable_error?({:http_error, status, _body}) when status >= 500, do: true
  def retryable_error?({:http_error, 429, _body}), do: true
  def retryable_error?({:http_error, _status, _body}), do: false

  @network_errors [:timeout, :econnrefused, :closed, :nxdomain, :econnreset, :ehostunreach]

  def retryable_error?(error) when error in @network_errors, do: true
  def retryable_error?({:error, reason}) when reason in @network_errors, do: true
  def retryable_error?(_error), do: false

  @doc """
  Builds a retry schedule showing attempt numbers and delays.

  The first attempt has 0 delay (immediate). Subsequent attempts use exponential backoff.

  ## Options

  - `:max_attempts` - Total number of attempts (default: 5)
  - `:base_delay` - Base delay in milliseconds (default: 1000)
  - `:max_delay` - Maximum delay cap (default: 30000)

  ## Example

      iex> Retry.build_schedule(max_attempts: 3, base_delay: 1000)
      [{1, 0}, {2, 1000}, {3, 2000}]
  """
  def build_schedule(opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)

    Enum.map(1..max_attempts, fn attempt ->
      delay =
        if attempt == 1 do
          0
        else
          calculate_delay(attempt - 1, opts)
        end

      {attempt, delay}
    end)
  end
end
