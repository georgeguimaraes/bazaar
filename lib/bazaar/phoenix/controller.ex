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

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_changeset(changeset))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
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
        |> json(Bazaar.Errors.not_found("checkout_session", id))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
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
        |> json(Bazaar.Errors.not_found("checkout_session", id))

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_changeset(changeset))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

  def complete_checkout(conn, %{"id" => id}) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)

    result =
      Telemetry.span_with_metadata([:bazaar, :checkout, :complete], %{}, fn ->
        case handler.complete_checkout(id, conn) do
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
        |> json(Bazaar.Errors.not_found("checkout_session", id))

      {:error, :invalid_state} ->
        conn
        |> put_status(:conflict)
        |> json(Bazaar.Errors.from_reason(:invalid_state))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
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
        |> json(Bazaar.Errors.not_found("checkout_session", id))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

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
        |> json(Bazaar.Errors.not_found("order", id))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
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
        |> json(Bazaar.Errors.not_found("order", id))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
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
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

  # Catalog

  def list_products(conn, params) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)
    {:ok, transformed_params} = Transformer.transform_request(params, protocol)

    result =
      Telemetry.span_with_metadata([:bazaar, :catalog, :list], %{}, fn ->
        case handler.list_products(transformed_params, conn) do
          {:ok, result} ->
            {result, %{count: length(result["products"] || [])}}

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
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

  def get_product(conn, %{"id" => id}) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)

    result =
      Telemetry.span_with_metadata([:bazaar, :catalog, :get], %{}, fn ->
        case handler.get_product(id, conn) do
          {:ok, _product} = result ->
            {result, %{product_id: id}}

          error ->
            {error, %{product_id: id}}
        end
      end)

    case result do
      {:ok, product} ->
        {:ok, response} = Transformer.transform_response(product, protocol)
        json(conn, response)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(Bazaar.Errors.not_found("product", id))

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

  def search_products(conn, params) do
    handler = conn.assigns.bazaar_handler
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)
    {:ok, transformed_params} = Transformer.transform_request(params, protocol)

    result =
      Telemetry.span_with_metadata([:bazaar, :catalog, :search], %{}, fn ->
        case handler.search_products(transformed_params, conn) do
          {:ok, result} ->
            {result, %{query: params["q"], count: length(result["products"] || [])}}

          error ->
            {error, %{query: params["q"]}}
        end
      end)

    case result do
      {:ok, result} ->
        {:ok, response} = Transformer.transform_response(result, protocol)
        json(conn, response)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(Bazaar.Errors.from_reason(reason))
    end
  end

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
        |> json(Bazaar.Errors.from_reason(reason))
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
