defmodule Bazaar.Telemetry.Logger do
  @moduledoc """
  Ready-to-use telemetry logger for Bazaar events.

  Logs all Bazaar operations with timing information to help identify
  performance bottlenecks.

  ## Usage

  Add to your application's `start/2` function:

      def start(_type, _args) do
        Bazaar.Telemetry.Logger.attach()

        children = [
          # ...
        ]

        Supervisor.start_link(children, strategy: :one_for_one)
      end

  ## Example Output

      [info] [Bazaar] checkout.create completed in 42ms (chk_123, incomplete)
      [info] [Bazaar] checkout.update completed in 15ms (chk_123, ready_for_complete)
      [info] [Bazaar] order.get completed in 8ms (ord_456, completed)
      [info] [Bazaar] webhook.handle completed in 23ms (order.shipped)
      [info] [Bazaar] discovery.profile completed in 2ms

  ## Options

  You can customize the logger by passing options to `attach/1`:

      Bazaar.Telemetry.Logger.attach(
        level: :debug,           # Log level (default: :info)
        handler_id: "my-logger"  # Custom handler ID (default: "bazaar-telemetry-logger")
      )

  ## Detaching

  To stop logging, call:

      Bazaar.Telemetry.Logger.detach()
  """

  require Logger

  @default_handler_id "bazaar-telemetry-logger"

  @events [
    # Checkout operations
    [:bazaar, :checkout, :create, :stop],
    [:bazaar, :checkout, :get, :stop],
    [:bazaar, :checkout, :update, :stop],
    [:bazaar, :checkout, :complete, :stop],
    [:bazaar, :checkout, :cancel, :stop],
    # Order operations
    [:bazaar, :order, :get, :stop],
    [:bazaar, :order, :cancel, :stop],
    # Identity operations
    [:bazaar, :identity, :link, :stop],
    # Webhook operations
    [:bazaar, :webhook, :handle, :stop],
    # Discovery
    [:bazaar, :discovery, :profile, :stop],
    # Plugs
    [:bazaar, :plug, :validate_request, :stop],
    [:bazaar, :plug, :idempotency, :stop],
    [:bazaar, :plug, :ucp_headers, :stop]
  ]

  @doc """
  Attaches telemetry handlers for logging Bazaar events.

  ## Options

    * `:level` - The log level to use (default: `:info`)
    * `:handler_id` - Custom handler ID (default: `"bazaar-telemetry-logger"`)

  """
  def attach(opts \\ []) do
    handler_id = Keyword.get(opts, :handler_id, @default_handler_id)
    level = Keyword.get(opts, :level, :info)

    :telemetry.attach_many(
      handler_id,
      @events,
      &__MODULE__.handle_event/4,
      %{level: level, handler_id: handler_id}
    )
  end

  @doc """
  Detaches the telemetry handlers.

  ## Options

    * `:handler_id` - The handler ID to detach (default: `"bazaar-telemetry-logger"`)

  """
  def detach(opts \\ []) do
    handler_id = Keyword.get(opts, :handler_id, @default_handler_id)
    :telemetry.detach(handler_id)
  end

  @doc false
  def handle_event(event, measurements, metadata, config) do
    duration = format_duration(measurements[:duration])
    event_name = format_event_name(event)
    details = extract_details(event_name, metadata)

    message =
      if details != "",
        do: "[Bazaar] #{event_name} completed in #{duration} #{details}",
        else: "[Bazaar] #{event_name} completed in #{duration}"

    Logger.log(config.level, message)
  end

  defp format_duration(nil), do: "?"

  defp format_duration(duration_ns) do
    duration_ms = System.convert_time_unit(duration_ns, :native, :millisecond)

    cond do
      duration_ms >= 1000 -> "#{Float.round(duration_ms / 1000, 2)}s"
      duration_ms >= 1 -> "#{duration_ms}ms"
      true -> "<1ms"
    end
  end

  defp format_event_name([:bazaar | rest]) do
    rest
    |> Enum.reject(&(&1 == :stop))
    |> Enum.map_join(".", &Atom.to_string/1)
  end

  # Checkout operations
  defp extract_details("checkout.create", meta) do
    format_checkout_details(meta)
  end

  defp extract_details("checkout.get", meta) do
    format_checkout_details(meta)
  end

  defp extract_details("checkout.update", meta) do
    format_checkout_details(meta)
  end

  defp extract_details("checkout.complete", meta) do
    format_checkout_details(meta)
  end

  defp extract_details("checkout.cancel", meta) do
    if meta[:checkout_id], do: "(#{meta[:checkout_id]})", else: ""
  end

  # Order operations
  defp extract_details("order.get", meta) do
    format_order_details(meta)
  end

  defp extract_details("order.cancel", meta) do
    if meta[:order_id], do: "(#{meta[:order_id]})", else: ""
  end

  # Identity operations
  defp extract_details("identity.link", meta) do
    if meta[:provider], do: "(#{meta[:provider]})", else: ""
  end

  # Webhook operations
  defp extract_details("webhook.handle", meta) do
    if meta[:event_type], do: "(#{meta[:event_type]})", else: ""
  end

  # Plug operations
  defp extract_details("plug.validate_request", meta) do
    case meta[:valid] do
      true -> "(valid)"
      false -> "(invalid)"
      _ -> ""
    end
  end

  defp extract_details("plug.idempotency", meta) do
    if meta[:key], do: "(key: #{meta[:key]})", else: "(no key)"
  end

  defp extract_details("plug.ucp_headers", meta) do
    if meta[:request_id], do: "(req: #{meta[:request_id]})", else: ""
  end

  # Discovery and fallback
  defp extract_details(_event, _meta), do: ""

  defp format_checkout_details(meta) do
    parts =
      [meta[:checkout_id], meta[:status]]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    if parts != "", do: "(#{parts})", else: ""
  end

  defp format_order_details(meta) do
    parts =
      [meta[:order_id], meta[:status]]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    if parts != "", do: "(#{parts})", else: ""
  end
end
