defmodule Bazaar.WebhookTest do
  use ExUnit.Case, async: true

  alias Bazaar.Signing.{HttpSignature, Key}
  alias Bazaar.Webhook

  @order %{
    "ucp" => %{"version" => "2026-08-25"},
    "id" => "order_123",
    "checkout_id" => "chk_456",
    "permalink_url" => "https://shop.example.com/orders/123",
    "line_items" => [%{"id" => "li_1"}],
    "totals" => []
  }

  @url "http://localhost:8284/webhooks/partners/test/events/order"

  # An http client that records every attempt and answers from a script.
  defp scripted(responses) do
    {:ok, log} = Agent.start_link(fn -> %{calls: [], responses: responses} end)

    client = fn url, body, headers ->
      Agent.get_and_update(log, fn %{calls: calls, responses: [response | rest]} = state ->
        {response,
         %{state | calls: calls ++ [%{url: url, body: body, headers: headers}], responses: rest}}
      end)
    end

    {client, fn -> Agent.get(log, & &1.calls) end}
  end

  defp header(headers, name), do: headers |> List.keyfind(name, 0) |> then(&(&1 && elem(&1, 1)))

  test "delivers the bare order with Webhook-Id and Webhook-Timestamp" do
    {client, calls} = scripted([{:ok, %{status: 200, body: ""}}])
    event = Webhook.event(@order, @url)

    assert {:ok, %{status: 200, attempts: 1}} = Webhook.deliver(event, http_client: client)

    [call] = calls.()
    assert call.url == @url
    assert JSON.decode!(call.body) == @order
    assert header(call.headers, "webhook-id") == event.id
    assert header(call.headers, "webhook-timestamp") == Integer.to_string(event.timestamp)
    assert header(call.headers, "idempotency-key") == event.id
    assert header(call.headers, "content-type") == "application/json"

    for name <- ~w(ucp-agent content-digest signature-input signature) do
      refute header(call.headers, name), "#{name} must not be sent unsigned"
    end
  end

  test "retries a 500 with the identical body, id and timestamp, then stops on 200" do
    {client, calls} =
      scripted([{:ok, %{status: 500, body: "retry"}}, {:ok, %{status: 200, body: ""}}])

    event = Webhook.event(@order, @url)

    assert {:ok, %{attempts: 2}} = Webhook.deliver(event, http_client: client, base_delay: 1)

    [first, second] = calls.()
    assert first.body == second.body
    assert header(first.headers, "webhook-id") == header(second.headers, "webhook-id")

    assert header(first.headers, "webhook-timestamp") ==
             header(second.headers, "webhook-timestamp")
  end

  test "treats a 4xx as final and gives up after max_attempts on transport errors" do
    {client, calls} = scripted([{:ok, %{status: 400, body: "bad"}}])

    assert {:error, {:http_error, 400, "bad"}} =
             Webhook.deliver(Webhook.event(@order, @url), http_client: client)

    assert length(calls.()) == 1

    {client, calls} = scripted(List.duplicate({:error, :econnrefused}, 3))

    assert {:error, {:max_attempts_reached, 3, :econnrefused}} =
             Webhook.deliver(Webhook.event(@order, @url), http_client: client, base_delay: 1)

    assert length(calls.()) == 3
  end

  test "signs every attempt so the platform can verify it with the published key" do
    key = Key.generate(:p256)
    {client, calls} = scripted([{:ok, %{status: 503, body: ""}}, {:ok, %{status: 200, body: ""}}])
    event = Webhook.event(@order, @url)

    assert {:ok, _} =
             Webhook.deliver(event,
               http_client: client,
               base_delay: 1,
               signer: {key, "https://shop.example.com/.well-known/ucp"}
             )

    for call <- calls.() do
      assert header(call.headers, "ucp-agent") ==
               ~s(profile="https://shop.example.com/.well-known/ucp")

      assert header(call.headers, "signature-input") =~
               ~s[("@method" "@authority" "@path" "content-digest" "content-type" "idempotency-key" "ucp-agent" "webhook-id" "webhook-timestamp")]

      request = %{method: "POST", url: call.url, headers: call.headers, body: call.body}
      assert :ok = HttpSignature.verify(request, Key.from_jwk(Key.public_jwk(key)))
    end
  end
end
