defmodule Bazaar.Telemetry do
  @moduledoc """
  Telemetry events emitted by Bazaar.

  Bazaar uses the standard `:telemetry` library to emit events for observability.
  You can attach handlers to these events for logging, metrics, or tracing.

  ## Events

  All events are emitted using `:telemetry.span/3`, which automatically generates
  `:start`, `:stop`, and `:exception` events.

  ### Checkout Events

  * `[:bazaar, :checkout, :create, :start]` - Emitted when checkout creation begins.
    * Measurement: `%{system_time: integer}`
    * Metadata: `%{}`

  * `[:bazaar, :checkout, :create, :stop]` - Emitted when checkout creation completes.
    * Measurement: `%{duration: integer}`
    * Metadata: `%{checkout_id: String.t(), status: atom()}`

  * `[:bazaar, :checkout, :create, :exception]` - Emitted when checkout creation fails.
    * Measurement: `%{duration: integer}`
    * Metadata: `%{kind: atom(), reason: term(), stacktrace: list()}`

  * `[:bazaar, :checkout, :get, :*]` - Retrieve checkout session.
    * Stop metadata: `%{checkout_id: String.t(), status: atom()}`

  * `[:bazaar, :checkout, :update, :*]` - Update checkout session.
    * Stop metadata: `%{checkout_id: String.t(), status: atom()}`

  * `[:bazaar, :checkout, :cancel, :*]` - Cancel checkout session.
    * Stop metadata: `%{checkout_id: String.t()}`

  ### Order Events

  * `[:bazaar, :order, :get, :*]` - Retrieve order.
    * Stop metadata: `%{order_id: String.t(), status: atom()}`

  * `[:bazaar, :order, :cancel, :*]` - Cancel order.
    * Stop metadata: `%{order_id: String.t()}`

  ### Identity Events

  * `[:bazaar, :identity, :link, :*]` - Link user identity via OAuth.
    * Stop metadata: `%{provider: String.t()}`

  ### Webhook Events

  * `[:bazaar, :webhook, :handle, :*]` - Process incoming webhook.
    * Stop metadata: `%{event_type: String.t()}`

  ### Discovery Events

  * `[:bazaar, :discovery, :profile, :*]` - Serve discovery profile.
    * Stop metadata: `%{}`

  ### Plug Events

  * `[:bazaar, :plug, :validate_request, :*]` - Request validation.
    * Stop metadata: `%{valid: boolean}`

  * `[:bazaar, :plug, :idempotency, :*]` - Idempotency key processing.
    * Stop metadata: `%{key: String.t() | nil}`

  * `[:bazaar, :plug, :ucp_headers, :*]` - UCP header extraction.
    * Stop metadata: `%{request_id: String.t()}`

  ## Quick Start with Built-in Logger

  For quick setup, use the built-in logger:

      # In your application's start/2
      Bazaar.Telemetry.Logger.attach()

  This logs all events with timing info. See `Bazaar.Telemetry.Logger` for options.

  ## Custom Handler

  For custom handling, attach your own handler:

      defmodule MyApp.BazaarLogger do
        require Logger

        def setup do
          events = [
            [:bazaar, :checkout, :create, :stop],
            [:bazaar, :checkout, :update, :stop],
            [:bazaar, :order, :get, :stop]
          ]

          :telemetry.attach_many("bazaar-logger", events, &handle_event/4, nil)
        end

        def handle_event([:bazaar, :checkout, :create, :stop], measurements, metadata, _config) do
          Logger.info("Created checkout \#{metadata.checkout_id} in \#{format_duration(measurements.duration)}")
        end

        defp format_duration(duration) do
          duration
          |> System.convert_time_unit(:native, :millisecond)
          |> then(&"\#{&1}ms")
        end
      end

  ## Integration with Metrics Libraries

  These telemetry events work with metrics libraries like:

  * `telemetry_metrics` - Define metrics based on these events
  * `prom_ex` - Export to Prometheus

  Example with `telemetry_metrics`:

      defmodule MyApp.Metrics do
        import Telemetry.Metrics

        def metrics do
          [
            counter("bazaar.checkout.create.stop.duration", unit: {:native, :millisecond}),
            summary("bazaar.checkout.create.stop.duration", unit: {:native, :millisecond}),
            counter("bazaar.order.get.stop.duration", unit: {:native, :millisecond})
          ]
        end
      end
  """

  @doc """
  Wraps a function call with telemetry span events.

  This is a convenience function used internally by Bazaar to emit
  consistent telemetry events.

  ## Example

      Bazaar.Telemetry.span([:bazaar, :checkout, :create], %{}, fn ->
        # ... create checkout logic ...
        {:ok, checkout}
      end)

  """
  def span(event_prefix, start_metadata, fun)
      when is_list(event_prefix) and is_function(fun, 0) do
    :telemetry.span(event_prefix, start_metadata, fn ->
      result = fun.()
      {result, start_metadata}
    end)
  end

  @doc """
  Wraps a function call with telemetry span events, allowing custom stop metadata.

  The function should return `{result, stop_metadata}` where `stop_metadata`
  is a map of additional metadata to include in the stop event.

  ## Example

      Bazaar.Telemetry.span_with_metadata([:bazaar, :checkout, :create], %{}, fn ->
        checkout = create_checkout()
        {{:ok, checkout}, %{checkout_id: checkout.id, status: checkout.status}}
      end)

  """
  def span_with_metadata(event_prefix, start_metadata, fun)
      when is_list(event_prefix) and is_function(fun, 0) do
    :telemetry.span(event_prefix, start_metadata, fn ->
      {result, stop_metadata} = fun.()
      {result, Map.merge(start_metadata, stop_metadata)}
    end)
  end
end
