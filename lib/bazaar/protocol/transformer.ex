defmodule Bazaar.Protocol.Transformer do
  @moduledoc """
  Transforms requests and responses between UCP and ACP protocol formats.

  ## Internal Format

  Bazaar uses UCP as its internal/canonical format. Handlers always receive
  and return data in UCP format. This module transforms ACP requests into
  UCP format before they reach the handler, and transforms UCP responses
  back to ACP format before sending to ACP clients.

      ACP Request → transform_request/2 → Handler (UCP) → transform_response/2 → ACP Response
      UCP Request → Handler (UCP) → UCP Response (no transformation)

  ## Transformations

  This module handles:
  - Address fields (street_address ↔ line_one, etc.)
  - Status values (incomplete ↔ not_ready_for_payment, etc.)
  - Item/line_item structure differences

  ## Address Field Mappings

  | UCP (internal)     | ACP         |
  |--------------------|-------------|
  | `street_address`   | `line_one`  |
  | `extended_address` | `line_two`  |
  | `address_locality` | `city`      |
  | `address_region`   | `state`     |
  | `address_country`  | `country`   |
  | `postal_code`      | `postal_code` (unchanged) |

  ## Item Mappings

  | UCP (internal) | ACP            |
  |----------------|----------------|
  | `items`        | `line_items`   |
  | `sku`          | `product.id`   |
  | `name`         | `product.name` |
  | `price`        | `base_amount`  |
  """

  alias Bazaar.Protocol

  @address_mappings [
    {"street_address", "line_one"},
    {"extended_address", "line_two"},
    {"address_locality", "city"},
    {"address_region", "state"},
    {"address_country", "country"}
  ]

  @doc """
  Transforms an incoming request from ACP format to internal (UCP) format.

  For `:ucp` protocol, returns the request unchanged.
  For `:acp` protocol, transforms address fields and line_items.
  """
  @spec transform_request(map(), Protocol.t()) :: {:ok, map()}
  def transform_request(request, :ucp), do: {:ok, request}

  def transform_request(request, :acp) do
    result =
      request
      |> transform_buyer_request()
      |> transform_line_items_to_items()

    {:ok, result}
  end

  @doc """
  Transforms an outgoing response from internal (UCP) format to protocol format.

  For `:ucp` protocol, returns the response unchanged.
  For `:acp` protocol, transforms status, address fields, and items.
  """
  @spec transform_response(map(), Protocol.t()) :: {:ok, map()}
  def transform_response(response, :ucp), do: {:ok, response}

  def transform_response(response, :acp) do
    result =
      response
      |> transform_status_to_acp()
      |> transform_buyer_response()
      |> transform_items_to_line_items()
      |> transform_fulfillment_response()

    {:ok, result}
  end

  @doc """
  Transforms address fields between UCP and ACP formats.

  ## Direction

  - `:acp_to_ucp` - Transforms ACP fields (line_one, city) to UCP fields (street_address, address_locality)
  - `:ucp_to_acp` - Transforms UCP fields to ACP fields
  """
  @spec transform_address(map() | nil, :acp_to_ucp | :ucp_to_acp) :: map() | nil
  def transform_address(nil, _direction), do: nil

  def transform_address(address, :acp_to_ucp) do
    Enum.reduce(@address_mappings, address, fn {ucp_key, acp_key}, acc ->
      case Map.pop(acc, acp_key) do
        {nil, acc} -> acc
        {value, acc} -> Map.put(acc, ucp_key, value)
      end
    end)
  end

  def transform_address(address, :ucp_to_acp) do
    Enum.reduce(@address_mappings, address, fn {ucp_key, acp_key}, acc ->
      case Map.pop(acc, ucp_key) do
        {nil, acc} -> acc
        {value, acc} -> Map.put(acc, acp_key, value)
      end
    end)
  end

  # Private: Request transformations

  defp transform_buyer_request(request) do
    case request do
      %{"buyer" => buyer} when is_map(buyer) ->
        transformed_buyer = transform_buyer_addresses(buyer, :acp_to_ucp)
        Map.put(request, "buyer", transformed_buyer)

      _ ->
        request
    end
  end

  defp transform_buyer_addresses(buyer, direction) do
    buyer
    |> maybe_transform_address("shipping_address", direction)
    |> maybe_transform_address("billing_address", direction)
  end

  defp maybe_transform_address(map, key, direction) do
    case map do
      %{^key => address} when is_map(address) ->
        Map.put(map, key, transform_address(address, direction))

      _ ->
        map
    end
  end

  defp transform_line_items_to_items(request) do
    case request do
      %{"line_items" => line_items} when is_list(line_items) ->
        items = Enum.map(line_items, &transform_line_item_to_item/1)

        request
        |> Map.delete("line_items")
        |> Map.put("items", items)

      _ ->
        request
    end
  end

  defp transform_line_item_to_item(line_item) do
    product = line_item["product"] || %{}

    base = %{
      "quantity" => line_item["quantity"]
    }

    base
    |> maybe_put("name", product["name"])
    |> maybe_put("sku", product["id"])
    |> maybe_put("price", line_item["base_amount"])
  end

  # Private: Response transformations

  defp transform_status_to_acp(response) do
    case response do
      %{"status" => status} when is_binary(status) ->
        acp_status =
          status |> String.to_existing_atom() |> Protocol.to_acp_status() |> to_string()

        Map.put(response, "status", acp_status)

      _ ->
        response
    end
  end

  defp transform_buyer_response(response) do
    case response do
      %{"buyer" => buyer} when is_map(buyer) ->
        transformed_buyer = transform_buyer_addresses(buyer, :ucp_to_acp)
        Map.put(response, "buyer", transformed_buyer)

      _ ->
        response
    end
  end

  defp transform_items_to_line_items(response) do
    case response do
      %{"items" => items} when is_list(items) ->
        line_items = Enum.map(items, &transform_item_to_line_item/1)

        response
        |> Map.delete("items")
        |> Map.put("line_items", line_items)

      _ ->
        response
    end
  end

  defp transform_item_to_line_item(item) do
    product = %{}
    product = maybe_put(product, "name", item["name"])
    product = maybe_put(product, "id", item["sku"])

    base = %{
      "quantity" => item["quantity"],
      "product" => product
    }

    maybe_put(base, "base_amount", item["price"])
  end

  defp transform_fulfillment_response(response) do
    case response do
      %{"fulfillment" => fulfillment} when is_map(fulfillment) ->
        transformed =
          fulfillment
          |> maybe_transform_address("destination", :ucp_to_acp)
          |> maybe_transform_address("origin", :ucp_to_acp)

        Map.put(response, "fulfillment", transformed)

      _ ->
        response
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
