defmodule Bazaar.Webhook do
  @moduledoc """
  Order event delivery to platforms.

  A platform learns about orders through webhooks: the full order document is
  POSTed to the `webhook_url` the platform advertises in its profile, with
  `Webhook-Id` and `Webhook-Timestamp` headers, once when the order is created
  and again whenever it changes. Failed deliveries are retried with the same
  body and headers, so the platform can deduplicate.

  Build the event once, then deliver it off the request path:

      {:ok, url} = Bazaar.Platform.webhook_url(conn.assigns.ucp_agent_profile, http_client: &MyApp.Http.get/1)
      event = Bazaar.Webhook.event(order, url)

      Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
        Bazaar.Webhook.deliver(event, http_client: &MyApp.Http.post/3, signer: {key, profile_url})
      end)

  Delivery blocks the calling process through its retries, so never run it
  inside the completion request: the platform is waiting on that response.

  ## Signing

  With a `:signer`, each attempt carries `UCP-Agent`, `Content-Digest`,
  `Signature-Input` and `Signature` per `Bazaar.Signing.HttpSignature`, and the
  platform verifies them against the `keys[]` in your discovery profile.
  Without one, none of the four headers is sent.
  """

  alias Bazaar.Signing.HttpSignature
  alias Bazaar.Telemetry
  alias Bazaar.Webhook.{Event, Retry}

  @default_max_attempts 3
  @default_base_delay 500
  @default_max_delay 5_000

  @doc "Builds the event for an order document and the platform's webhook URL."
  def event(order, url), do: Event.new(order, url)

  @doc """
  Delivers an event, retrying transport errors, 5xx and 429 with exponential
  backoff. A 4xx is final.

  ## Options

  - `:http_client` - required, `fn url, body, headers -> {:ok, %{status: integer, body: term}} | {:error, reason} end`
  - `:signer` - `{Bazaar.Signing.Key.t(), profile_url}`; `profile_url` is this
    business's `/.well-known/ucp`, sent as `UCP-Agent` so the platform knows
    whose keys to check
  - `:max_attempts` (#{@default_max_attempts}), `:base_delay` (#{@default_base_delay}ms), `:max_delay` (#{@default_max_delay}ms)

  Returns `{:ok, %{status: status, attempts: n}}`, `{:error, {:http_error, status, body}}`
  for a final 4xx, or `{:error, {:max_attempts_reached, n, last_error}}`.
  """
  def deliver(%Event{} = event, opts) do
    http_client = Keyword.fetch!(opts, :http_client)

    retry = [
      max_attempts: Keyword.get(opts, :max_attempts, @default_max_attempts),
      base_delay: Keyword.get(opts, :base_delay, @default_base_delay),
      max_delay: Keyword.get(opts, :max_delay, @default_max_delay)
    ]

    attempt(event, http_client, Keyword.get(opts, :signer), retry, 1)
  end

  defp attempt(event, http_client, signer, retry, n) do
    result =
      Telemetry.span_with_metadata(
        [:bazaar, :webhook, :deliver],
        %{webhook_id: event.id, attempt: n},
        fn ->
          case http_client.(event.url, event.body, headers(event, signer)) do
            {:ok, %{status: status}} when status in 200..299 ->
              {{:ok, %{status: status, attempts: n}}, %{status: status}}

            {:ok, %{status: status, body: body}} ->
              {{:error, {:http_error, status, body}}, %{status: status}}

            {:error, reason} ->
              {{:error, reason}, %{}}
          end
        end
      )

    case result do
      {:ok, _} = ok ->
        ok

      {:error, error} ->
        cond do
          not Retry.retryable_error?(error) -> {:error, error}
          n >= retry[:max_attempts] -> {:error, {:max_attempts_reached, n, error}}
          true -> retry_after(event, http_client, signer, retry, n, error)
        end
    end
  end

  defp retry_after(event, http_client, signer, retry, n, _error) do
    Process.sleep(Retry.calculate_delay(n, retry))
    attempt(event, http_client, signer, retry, n + 1)
  end

  @doc false
  def headers(%Event{} = event, nil) do
    [
      {"content-type", "application/json"},
      {"webhook-id", event.id},
      {"webhook-timestamp", Integer.to_string(event.timestamp)},
      {"idempotency-key", event.id}
    ]
  end

  def headers(%Event{} = event, {key, profile_url}) do
    headers = headers(event, nil) ++ [{"ucp-agent", ~s(profile="#{profile_url}")}]
    request = %{method: "POST", url: event.url, headers: headers, body: event.body}

    HttpSignature.sign(request, key,
      components: ["idempotency-key", "ucp-agent", "webhook-id", "webhook-timestamp"]
    )
  end
end
