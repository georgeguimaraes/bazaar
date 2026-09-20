defmodule Bazaar.Webhook do
  @moduledoc """
  Order event delivery to platforms.

  A platform learns about orders through webhooks: the full order document is
  POSTed to the `webhook_url` the platform advertises in its profile, with
  `Webhook-Id` and `Webhook-Timestamp` headers, once when the order is created
  and again whenever it changes. Failed deliveries are retried with the same
  body and headers, so the platform can deduplicate.

  A shop that names an `http_client/0` and a `signing_key/0` gets this for
  free: `Bazaar.Shop`'s `order_placed/2` and `order_updated/2` call
  `deliver_order/3`, which finds the platform's webhook URL, signs, and
  delivers off the request path.

      defmodule MyApp.Shop do
        use Bazaar.Shop

        @impl true
        def http_client, do: %{get: &MyApp.Http.get/1, post: &MyApp.Http.post/3}

        @impl true
        def signing_key, do: MyApp.Signing.key()
      end

  `deliver_order/3` also takes a platform profile URL instead of a conn, for
  changes that don't come from a request (an order shipping from your own
  system). `event/2` and `deliver/2` are the pieces underneath, for a shop
  that wants to own the delivery: note that `deliver/2` blocks the calling
  process through its retries, so never run it inside the completion request.

  ## Signing

  With a `:signer`, each attempt carries `UCP-Agent`, `Content-Digest`,
  `Signature-Input` and `Signature` per `Bazaar.Signing.HttpSignature`, and the
  platform verifies them against the `keys[]` in your discovery profile.
  Without one, none of the four headers is sent.
  """

  require Logger

  alias Bazaar.Signing.HttpSignature
  alias Bazaar.Telemetry
  alias Bazaar.Webhook.{Event, Retry}

  @default_max_attempts 3
  @default_base_delay 500
  @default_max_delay 5_000

  @doc "Builds the event for an order document and the platform's webhook URL."
  def event(order, url), do: Event.new(order, url)

  @doc """
  Delivers an order to the platform that asked for it: reads the platform's
  `webhook_url` from its profile, signs with the shop's key, and runs the
  delivery under the shop's task supervisor, or inline when it names none.
  The profile is fetched per delivery, so a platform that moves its endpoint
  is followed; deliveries run off the request path, where that costs nothing.

  The third argument is the conn of the request that changed the order (its
  `ucp_agent_profile` assign names the platform) or a platform profile URL
  you stored. Returns `:ok`, or `{:error, reason}` when the shop has no HTTP
  client, no platform was named, or its profile advertises no webhook URL.
  Never raises.
  """
  def deliver_order(order, shop, conn_or_profile_url) do
    with {:ok, client} <- http_client(shop),
         {:ok, profile_url} <- profile_url(conn_or_profile_url),
         {:ok, url} <- Bazaar.Platform.webhook_url(profile_url, http_client: client.get) do
      event = event(order, url)
      deliver_under(shop, event)
      :ok
    end
  end

  defp http_client(shop) do
    case shop.http_client() do
      %{get: get, post: post} when is_function(get, 1) and is_function(post, 3) ->
        {:ok, %{get: get, post: post}}

      _ ->
        {:error, :no_http_client}
    end
  end

  defp profile_url(%Plug.Conn{} = conn) do
    case conn.assigns[:ucp_agent_profile] do
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, :no_platform}
    end
  end

  defp profile_url(url) when is_binary(url), do: {:ok, url}
  defp profile_url(_other), do: {:error, :no_platform}

  defp deliver_under(shop, event) do
    %{post: post} = shop.http_client()
    signer = signer(shop)
    run = fn -> deliver(event, http_client: post, signer: signer) end

    case shop.webhook_task_supervisor() do
      nil -> run.()
      name -> Task.Supervisor.start_child(name, run)
    end
  end

  defp signer(shop) do
    case shop.signing_key() do
      nil ->
        Logger.warning(
          "[Bazaar] #{inspect(shop)} has no signing_key/0, so order webhooks go unsigned; " <>
            "the spec has them signed and platforms may reject them"
        )

        nil

      key ->
        {key, shop.base_url() <> "/.well-known/ucp"}
    end
  end

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
