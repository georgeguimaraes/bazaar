defmodule Bazaar.Phoenix.Controller do
  @moduledoc """
  Phoenix controller that dispatches to your UCP/ACP handler.

  This controller is used internally by `Bazaar.Phoenix.Router`.
  You don't need to use it directly.

  ## Protocol Transformation

  Bazaar uses UCP as its internal format. Your handler always works with
  UCP field names and status values. The controller handles transformation:

  - **ACP protocol**: transforms requests from ACP to UCP before calling your
    handler, and transforms responses from UCP back to ACP
  - **UCP protocol**: passes requests and responses through unchanged
  """

  use Phoenix.Controller, formats: [:json]

  alias Bazaar.DiscoveryProfile
  alias Bazaar.Protocol.Transformer
  alias Bazaar.Telemetry

  # Discovery

  def discovery(conn, _params) do
    handler = conn.assigns.bazaar_handler
    base_url = get_base_url(conn)

    profile =
      Telemetry.span([:bazaar, :discovery, :profile], %{}, fn ->
        DiscoveryProfile.from_handler(handler, base_url: base_url)
      end)

    json(conn, profile)
  end

  # Checkout

  def create_checkout(conn, params) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)
    {:ok, transformed_params} = Transformer.transform_request(params, protocol)

    result =
      Telemetry.span_with_metadata([:bazaar, :checkout, :create], %{}, fn ->
        case handler.create_checkout(transformed_params, conn) do
          {:ok, checkout} = result ->
            {result, %{checkout_id: checkout["id"], status: checkout["status"]}}

          error ->
            {error, %{}}
        end
      end)

    case result do
      {:ok, checkout} ->
        {:ok, response} = Transformer.transform_response(checkout, protocol)

        conn
        |> put_status(:created)
        |> json(response)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.response(:not_found, protocol: protocol))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(changeset, protocol: protocol))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(reason, protocol: protocol))
    end
  end

  def get_checkout(conn, %{"id" => id}) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)

    result =
      Telemetry.span_with_metadata([:bazaar, :checkout, :get], %{}, fn ->
        case handler.get_checkout(id, conn) do
          {:ok, checkout} = result ->
            {result, %{checkout_id: id, status: checkout["status"]}}

          error ->
            {error, %{checkout_id: id}}
        end
      end)

    case result do
      {:ok, checkout} ->
        {:ok, response} = Transformer.transform_response(checkout, protocol)
        json(conn, response)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.response(:not_found, protocol: protocol))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(reason, protocol: protocol))
    end
  end

  def update_checkout(conn, %{"id" => id} = params) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)
    update_params = Map.delete(params, "id")
    {:ok, transformed_params} = Transformer.transform_request(update_params, protocol)

    result =
      Telemetry.span_with_metadata([:bazaar, :checkout, :update], %{}, fn ->
        case handler.update_checkout(id, transformed_params, conn) do
          {:ok, checkout} = result ->
            {result, %{checkout_id: id, status: checkout["status"]}}

          error ->
            {error, %{checkout_id: id}}
        end
      end)

    case result do
      {:ok, checkout} ->
        {:ok, response} = Transformer.transform_response(checkout, protocol)
        json(conn, response)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.response(:not_found, protocol: protocol))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(changeset, protocol: protocol))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(reason, protocol: protocol))
    end
  end

  def complete_checkout(conn, %{"id" => id}) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)
    {:ok, body} = Transformer.transform_request(body_params(conn), protocol)

    result =
      Telemetry.span_with_metadata([:bazaar, :checkout, :complete], %{}, fn ->
        case handler.complete_checkout(id, body, conn) do
          {:ok, checkout} = result ->
            {result, %{checkout_id: id, status: checkout["status"]}}

          error ->
            {error, %{checkout_id: id}}
        end
      end)

    case result do
      {:ok, checkout} ->
        {:ok, response} = Transformer.transform_response(checkout, protocol)
        json(conn, response)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.response(:not_found, protocol: protocol))

      {:error, :invalid_state} ->
        conn
        |> put_status(:conflict)
        |> json(Bazaar.Errors.response(:invalid_state, protocol: protocol))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(reason, protocol: protocol))
    end
  end

  def cancel_checkout(conn, %{"id" => id}) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)

    result =
      Telemetry.span_with_metadata([:bazaar, :checkout, :cancel], %{}, fn ->
        case handler.cancel_checkout(id, conn) do
          {:ok, _checkout} = result ->
            {result, %{checkout_id: id}}

          error ->
            {error, %{checkout_id: id}}
        end
      end)

    case result do
      {:ok, checkout} ->
        {:ok, response} = Transformer.transform_response(checkout, protocol)
        json(conn, response)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.response(:not_found, protocol: protocol))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(reason, protocol: protocol))
    end
  end

  defp body_params(%{body_params: %{} = body}) when not is_struct(body), do: body
  defp body_params(_conn), do: %{}

  # Orders

  def get_order(conn, %{"id" => id}) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)

    result =
      Telemetry.span_with_metadata([:bazaar, :order, :get], %{}, fn ->
        case handler.get_order(id, conn) do
          {:ok, order} = result ->
            {result, %{order_id: id, status: order["status"]}}

          error ->
            {error, %{order_id: id}}
        end
      end)

    case result do
      {:ok, order} ->
        {:ok, response} = Transformer.transform_response(order, protocol)
        json(conn, response)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.response(:not_found, protocol: protocol))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(reason, protocol: protocol))
    end
  end

  def update_order(conn, %{"id" => id} = params) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)
    update_params = Map.delete(params, "id")

    result =
      Telemetry.span_with_metadata([:bazaar, :order, :update], %{}, fn ->
        case handler.update_order(id, update_params, conn) do
          {:ok, order} = result ->
            {result, %{order_id: id, status: order["status"]}}

          error ->
            {error, %{order_id: id}}
        end
      end)

    case result do
      {:ok, order} ->
        {:ok, response} = Transformer.transform_response(order, protocol)
        json(conn, response)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.response(:not_found, protocol: protocol))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(reason, protocol: protocol))
    end
  end

  def cancel_order(conn, %{"id" => id}) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)

    result =
      Telemetry.span_with_metadata([:bazaar, :order, :cancel], %{}, fn ->
        case handler.cancel_order(id, conn) do
          {:ok, _order} = result ->
            {result, %{order_id: id}}

          error ->
            {error, %{order_id: id}}
        end
      end)

    case result do
      {:ok, order} ->
        {:ok, response} = Transformer.transform_response(order, protocol)
        json(conn, response)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.response(:not_found, protocol: protocol))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(reason, protocol: protocol))
    end
  end

  # Identity

  def link_identity(conn, params) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)
    {:ok, transformed_params} = Transformer.transform_request(params, protocol)

    result =
      Telemetry.span_with_metadata([:bazaar, :identity, :link], %{}, fn ->
        case handler.link_identity(transformed_params, conn) do
          {:ok, _result} = result ->
            {result, %{provider: params["provider"]}}

          error ->
            {error, %{}}
        end
      end)

    case result do
      {:ok, result} ->
        {:ok, response} = Transformer.transform_response(result, protocol)
        json(conn, response)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(reason, protocol: protocol))
    end
  end

  # Cart (UCP only)

  def create_cart(conn, params) do
    cart(conn, :create, fn handler -> handler.create_cart(params, conn) end, :created)
  end

  def get_cart(conn, %{"id" => id}) do
    cart(conn, :get, fn handler -> handler.get_cart(id, conn) end)
  end

  def update_cart(conn, %{"id" => id} = params) do
    cart(conn, :update, fn handler -> handler.update_cart(id, Map.delete(params, "id"), conn) end)
  end

  def cancel_cart(conn, %{"id" => id}) do
    cart(conn, :cancel, fn handler -> handler.cancel_cart(id, conn) end)
  end

  defp cart(conn, operation, fun, status \\ :ok) do
    handler = conn.assigns.bazaar_handler

    result =
      Telemetry.span_with_metadata([:bazaar, :cart, operation], %{}, fn ->
        case fun.(handler) do
          {:ok, cart} = result -> {result, %{cart_id: cart["id"]}}
          error -> {error, %{}}
        end
      end)

    case result do
      {:ok, cart} ->
        conn |> put_status(status) |> json(cart)

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(Bazaar.Errors.response(:not_found))

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(Bazaar.Errors.response(reason))
    end
  end

  # Catalog (UCP only: the binding is three POSTs, every one answering 200)

  def search_products(conn, params) do
    catalog(conn, :search, fn handler -> handler.search_products(params, conn) end)
  end

  def lookup_products(conn, %{"ids" => [_ | _]} = params) do
    catalog(conn, :lookup, fn handler -> handler.lookup_products(params, conn) end)
  end

  def lookup_products(conn, _params), do: missing(conn, :missing_ids)

  def get_product(conn, %{"id" => _} = params) do
    catalog(conn, :get, fn handler -> handler.get_product(params, conn) end)
  end

  def get_product(conn, _params), do: missing(conn, :missing_id)

  # Location (UCP only, same binding shape as the catalog)

  def search_locations(conn, params) do
    discovery_action(
      conn,
      [:bazaar, :location, :search],
      &Bazaar.Location.envelope(&1, :search),
      fn handler ->
        handler.search_locations(params, conn)
      end
    )
  end

  def lookup_locations(conn, %{"ids" => [_ | _]} = params) do
    discovery_action(
      conn,
      [:bazaar, :location, :lookup],
      &Bazaar.Location.envelope(&1, :lookup),
      fn handler ->
        handler.lookup_locations(params, conn)
      end
    )
  end

  def lookup_locations(conn, _params), do: missing(conn, :missing_ids)

  # The schemas require them, so a handler never sees a body without.
  defp missing(conn, reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(Bazaar.Errors.response(reason))
  end

  defp catalog(conn, operation, fun) do
    envelope = &Bazaar.Catalog.envelope(&1, catalog_capability(operation))
    discovery_action(conn, [:bazaar, :catalog, operation], envelope, fun, operation == :get)
  end

  defp catalog_capability(:search), do: :search
  defp catalog_capability(_lookup_or_get), do: :lookup

  # Discovery operations answer 200 with an enveloped document; a single
  # unknown resource is the spec's error document, still a 200.
  defp discovery_action(conn, span, envelope, fun, not_found_in_band? \\ false) do
    handler = conn.assigns.bazaar_handler

    result =
      Telemetry.span_with_metadata(span, %{}, fn ->
        case fun.(handler) do
          {:ok, document} -> {{:ok, document}, %{count: document_count(document)}}
          error -> {error, %{}}
        end
      end)

    case result do
      {:ok, document} ->
        json(conn, envelope.(document))

      {:error, :not_found} when not_found_in_band? ->
        json(conn, Bazaar.Errors.response(:not_found))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(reason))
    end
  end

  defp document_count(%{"products" => list}) when is_list(list), do: length(list)
  defp document_count(%{"locations" => list}) when is_list(list), do: length(list)
  defp document_count(%{"product" => _}), do: 1
  defp document_count(_document), do: 0

  # Webhooks

  def webhook(conn, params) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)
    {:ok, transformed_params} = Transformer.transform_request(params, protocol)

    result =
      Telemetry.span_with_metadata([:bazaar, :webhook, :handle], %{}, fn ->
        case handler.handle_webhook(transformed_params) do
          {:ok, _result} = result ->
            {result, %{event_type: params["type"] || params["event_type"]}}

          error ->
            {error, %{}}
        end
      end)

    case result do
      {:ok, _result} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "processed"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.response(reason, protocol: protocol))
    end
  end

  # Helpers

  defp get_base_url(conn) do
    # Check x-forwarded-proto header for reverse proxy setups (Tailscale, ngrok, etc.)
    forwarded_proto = get_req_header(conn, "x-forwarded-proto") |> List.first()

    scheme =
      cond do
        forwarded_proto in ["https", "http"] -> forwarded_proto
        conn.scheme == :https -> "https"
        true -> "http"
      end

    # For standard ports, omit the port suffix
    port_suffix = if conn.port in [80, 443], do: "", else: ":#{conn.port}"

    # If behind reverse proxy on standard HTTPS port, don't include port
    if forwarded_proto == "https" do
      "#{scheme}://#{conn.host}"
    else
      "#{scheme}://#{conn.host}#{port_suffix}"
    end
  end
end
