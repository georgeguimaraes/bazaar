defmodule Bazaar.Protocol.Transformer do
  @moduledoc """
  Translates between UCP, bazaar's internal format, and ACP as the bundled
  `#{Bazaar.Protocol.acp_version()}` schemas define it.

      ACP request → transform_request/2 → handler (UCP) → transform_response/2 → ACP response
      UCP request → handler (UCP) → UCP response (untouched)

  The two protocols model the same checkout with different names and
  nesting. Requests: ACP `line_items` (or the RFC's `items`) of `{id,
  quantity}` become UCP line items with an `item`; `fulfillment_details`
  becomes one shipping method with the address as its selected destination;
  `selected_fulfillment_options` selects that method's option; `payment_data`
  becomes a payment instrument. Responses are rebuilt from the UCP checkout
  document: line items get `item.name` and `unit_amount`, totals get
  `display_text`, fulfillment options and the selection are lifted out of
  the methods, messages take ACP's codes and severities, and ACP's closed
  objects (`buyer`, `links`, addresses) carry only the fields ACP knows.

  Two limits worth knowing. ACP's `selected_fulfillment_options.item_ids`
  are item ids, UCP groups hold line item ids, so a selection applies to the
  method's whole line item set (ACP models one shipping group). And ACP's
  `capabilities.payment.handlers` need a descriptor UCP doesn't carry (`spec`,
  `psp`, `config_schema`, ...): registry entries in `ucp.payment_handlers`
  that include those fields are advertised, the rest are left out.

  ## Address fields

  | UCP                | ACP         |
  |--------------------|-------------|
  | `street_address`   | `line_one`  |
  | `extended_address` | `line_two`  |
  | `address_locality` | `city`      |
  | `address_region`   | `state`     |
  | `address_country`  | `country`   |
  | `first_name` + `last_name` | `name` |
  """

  alias Bazaar.Protocol

  @address_mappings [
    {"street_address", "line_one"},
    {"extended_address", "line_two"},
    {"address_locality", "city"},
    {"address_region", "state"},
    {"address_country", "country"}
  ]

  @acp_address_required ~w(name line_one city state country postal_code)
  @acp_buyer_fields ~w(email first_name last_name full_name phone_number)
  @acp_link_types ~w(terms_of_use privacy_policy return_policy shipping_policy contact_us about_us faq support)
  @acp_handler_fields ~w(id name version spec requires_delegate_payment requires_pci_compliance psp config_schema instrument_schemas config)

  @error_codes %{
    "not_found" => "not_found",
    "out_of_stock" => "out_of_stock",
    "missing" => "missing",
    "payment_failed" => "payment_declined",
    "payment_declined" => "payment_declined",
    "invalid_request" => "invalid",
    "expired" => "expired",
    "conflict" => "conflict",
    "unsupported" => "unsupported"
  }

  @warning_codes %{
    "quantity_adjusted" => "low_stock",
    "low_stock" => "low_stock",
    "price_change" => "price_change",
    "shipping_delay" => "shipping_delay"
  }

  @severities %{
    "unrecoverable" => "critical",
    "requires_buyer_input" => "high",
    "requires_buyer_review" => "medium",
    "recoverable" => "low"
  }

  # Requests

  @doc """
  An incoming request in UCP terms. `:ucp` requests pass through; `:acp`
  requests are translated as described above.
  """
  @spec transform_request(map(), Protocol.t()) :: {:ok, map()}
  def transform_request(request, :ucp), do: {:ok, request}

  def transform_request(request, :acp) do
    ucp =
      request
      |> Map.take(["id", "currency", "buyer"])
      |> put_line_items(request)
      |> put_fulfillment(request)
      |> put_discounts(request)
      |> put_payment(request)

    {:ok, ucp}
  end

  defp put_line_items(ucp, request) do
    case request["line_items"] || request["items"] do
      list when is_list(list) -> Map.put(ucp, "line_items", Enum.map(list, &line_item_to_ucp/1))
      _ -> ucp
    end
  end

  # Already UCP-shaped entries pass through; ACP's {id, quantity} gets its item.
  defp line_item_to_ucp(%{"item" => %{}} = line), do: line

  defp line_item_to_ucp(%{"id" => id} = entry),
    do: %{"item" => %{"id" => id}, "quantity" => entry["quantity"] || 1}

  defp line_item_to_ucp(entry), do: entry

  defp put_fulfillment(ucp, request) do
    method =
      %{"id" => "method_1", "type" => "shipping"}
      |> put_destination(request["fulfillment_details"])
      |> put_selection(request["selected_fulfillment_options"])

    if map_size(method) > 2,
      do: Map.put(ucp, "fulfillment", %{"methods" => [method]}),
      else: ucp
  end

  defp put_destination(method, %{"address" => address} = details) when is_map(address) do
    destination =
      address
      |> transform_address(:acp_to_ucp)
      |> Map.merge(split_name(details["name"] || address["name"]))
      |> maybe_put("phone_number", details["phone_number"])
      |> Map.put("id", "dest_1")

    Map.merge(method, %{"destinations" => [destination], "selected_destination_id" => "dest_1"})
  end

  defp put_destination(method, _details), do: method

  defp put_selection(method, [%{"option_id" => option_id} | _]),
    do: Map.put(method, "groups", [%{"id" => "group_1", "selected_option_id" => option_id}])

  defp put_selection(method, _selection), do: method

  defp put_discounts(ucp, request) do
    codes = (get_in(request, ["discounts", "codes"]) || []) ++ (request["coupons"] || [])

    if Map.has_key?(request, "discounts") or Map.has_key?(request, "coupons"),
      do: Map.put(ucp, "discounts", %{"codes" => Enum.uniq(codes)}),
      else: ucp
  end

  defp put_payment(ucp, %{"payment_data" => %{} = payment}) do
    instrument =
      (payment["instrument"] || %{})
      |> maybe_put("handler_id", payment["handler_id"])
      |> maybe_put("billing_address", transform_address(payment["billing_address"], :acp_to_ucp))

    Map.put(ucp, "payment", %{"instruments" => [instrument]})
  end

  defp put_payment(ucp, _request), do: ucp

  # Responses

  @doc """
  An outgoing checkout document in the protocol's terms. `:ucp` documents
  pass through; `:acp` gets a checkout session built from the UCP one.
  """
  @spec transform_response(map(), Protocol.t()) :: {:ok, map()}
  def transform_response(response, :ucp), do: {:ok, response}

  def transform_response(checkout, :acp) do
    line_items = checkout["line_items"] || []
    {options, selected, details} = fulfillment_to_acp(checkout["fulfillment"], line_items)

    session =
      %{
        "protocol" => %{"version" => Protocol.acp_version()},
        "id" => checkout["id"],
        "currency" => checkout["currency"],
        "line_items" => Enum.map(line_items, &line_item_to_acp/1),
        "totals" => totals_to_acp(checkout["totals"]),
        "fulfillment_options" => options,
        "messages" => Enum.map(checkout["messages"] || [], &message_to_acp/1),
        "links" => links_to_acp(checkout["links"]),
        "capabilities" => capabilities_to_acp(checkout["ucp"])
      }
      |> maybe_put("status", status_to_acp(checkout["status"]))
      |> maybe_put("buyer", buyer_to_acp(checkout["buyer"]))
      |> maybe_put("selected_fulfillment_options", non_empty(selected))
      |> maybe_put("fulfillment_details", details)
      |> maybe_put("discounts", discounts_to_acp(checkout["discounts"]))
      |> maybe_put("order", order_to_acp(checkout["order"], checkout["id"]))

    {:ok, session}
  end

  defp status_to_acp(status) when is_binary(status),
    do: status |> Protocol.to_acp_status() |> to_string()

  defp status_to_acp(_status), do: nil

  defp line_item_to_acp(line) do
    item = line["item"] || %{}

    %{
      "id" => line["id"],
      "item" =>
        %{"id" => item["id"]}
        |> maybe_put("name", item["title"])
        |> maybe_put("unit_amount", item["price"]),
      "quantity" => line["quantity"],
      "totals" => totals_to_acp(line["totals"])
    }
  end

  defp totals_to_acp(totals) do
    for %{"type" => type, "amount" => amount} = total <- totals || [] do
      %{
        "type" => type,
        "display_text" => total["display_text"] || humanize(type),
        "amount" => amount
      }
    end
  end

  defp humanize(type), do: type |> String.replace("_", " ") |> String.capitalize()

  defp fulfillment_to_acp(nil, _line_items), do: {[], [], nil}

  defp fulfillment_to_acp(%{"methods" => methods}, line_items) do
    item_ids = Map.new(line_items, &{&1["id"], get_in(&1, ["item", "id"])})

    options =
      for method <- methods, group <- method["groups"] || [], option <- group["options"] || [] do
        %{
          "type" => method_type(method["type"]),
          "id" => option["id"],
          "title" => option["title"],
          "totals" => totals_to_acp(option["totals"])
        }
        |> maybe_put("description", option["description"])
      end
      |> Enum.uniq_by(& &1["id"])

    selected =
      for method <- methods,
          %{"selected_option_id" => option_id} = group when is_binary(option_id) <-
            method["groups"] || [] do
        %{
          "type" => method_type(method["type"]),
          "option_id" => option_id,
          "item_ids" => Enum.map(group["line_item_ids"] || [], &Map.get(item_ids, &1, &1))
        }
      end

    details =
      Enum.find_value(methods, fn method ->
        destination =
          Enum.find(
            method["destinations"] || [],
            &(&1["id"] == method["selected_destination_id"])
          )

        destination && destination_to_acp(destination)
      end)

    {options, selected, details}
  end

  defp fulfillment_to_acp(_fulfillment, _line_items), do: {[], [], nil}

  defp method_type(type) when type in ["shipping", "pickup", "digital", "local_delivery"],
    do: type

  defp method_type(_type), do: "shipping"

  defp destination_to_acp(destination) do
    address = transform_address(destination, :ucp_to_acp)

    %{"address" => address}
    |> maybe_put("name", non_empty(address["name"]))
    |> maybe_put("phone_number", destination["phone_number"])
  end

  # ACP message codes and severities are closed enums; UCP's are open strings.
  defp message_to_acp(%{"type" => type} = message) do
    base = %{
      "type" => type,
      "content_type" => message["content_type"] || "plain",
      "content" => message["content"] || "",
      "severity" => Map.get(@severities, message["severity"], "info")
    }

    base
    |> maybe_put("code", message_code(type, message["code"]))
    |> maybe_put("param", message["path"])
  end

  defp message_code("error", code), do: Map.get(@error_codes, code, "invalid")
  defp message_code("warning", code), do: Map.get(@warning_codes, code, "low_stock")
  defp message_code(_info, _code), do: nil

  defp links_to_acp(links) do
    for %{"url" => url} = link <- links || [],
        type = link_type(link["type"]),
        type in @acp_link_types do
      %{"type" => type, "url" => url} |> maybe_put("title", link["title"])
    end
  end

  defp link_type("terms_of_service"), do: "terms_of_use"
  defp link_type(type), do: type

  defp buyer_to_acp(%{"email" => email} = buyer) when is_binary(email),
    do: Map.take(buyer, @acp_buyer_fields)

  defp buyer_to_acp(_buyer), do: nil

  defp discounts_to_acp(%{} = discounts) do
    applied =
      for %{"code" => code, "amount" => amount} = entry <- discounts["applied"] || [] do
        %{
          "id" => code,
          "code" => code,
          "coupon" => %{"id" => code, "name" => entry["title"] || code},
          "amount" => amount
        }
        |> maybe_put("allocations", entry["allocations"])
      end

    %{"codes" => discounts["codes"] || []} |> maybe_put("applied", non_empty(applied))
  end

  defp discounts_to_acp(_discounts), do: nil

  defp capabilities_to_acp(%{"payment_handlers" => %{} = registry}) do
    handlers =
      for {namespace, entries} <- registry,
          entry <- entries,
          descriptor = Map.put_new(entry, "name", namespace),
          Enum.all?(@acp_handler_fields, &Map.has_key?(descriptor, &1)) do
        Map.take(descriptor, @acp_handler_fields)
      end

    if handlers == [], do: %{}, else: %{"payment" => %{"handlers" => handlers}}
  end

  defp capabilities_to_acp(_ucp), do: %{}

  defp order_to_acp(%{"id" => id} = order, checkout_id) do
    %{"id" => id, "checkout_session_id" => checkout_id, "permalink_url" => order["permalink_url"]}
  end

  defp order_to_acp(_order, _checkout_id), do: nil

  # Addresses

  @doc """
  An address in the other protocol's fields. `:acp_to_ucp` also splits
  `name` into `first_name` and `last_name`; `:ucp_to_acp` joins them, keeps
  only ACP's fields and fills the ones ACP requires with `""` when UCP has
  no value (ACP's own examples do the same).
  """
  @spec transform_address(map() | nil, :acp_to_ucp | :ucp_to_acp) :: map() | nil
  def transform_address(nil, _direction), do: nil

  def transform_address(address, :acp_to_ucp) do
    {name, address} = Map.pop(address, "name")

    @address_mappings
    |> Enum.reduce(address, fn {ucp_key, acp_key}, acc -> rename(acc, acp_key, ucp_key) end)
    |> Map.merge(split_name(name))
  end

  def transform_address(address, :ucp_to_acp) do
    renamed =
      Enum.reduce(@address_mappings, address, fn {ucp_key, acp_key}, acc ->
        rename(acc, ucp_key, acp_key)
      end)

    name =
      [address["first_name"], address["last_name"]] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

    renamed
    |> Map.take(["line_two" | @acp_address_required])
    |> Map.put("name", name)
    |> then(&Enum.reduce(@acp_address_required, &1, fn key, acc -> Map.put_new(acc, key, "") end))
  end

  defp rename(map, from, to) do
    case Map.pop(map, from) do
      {nil, map} -> map
      {value, map} -> Map.put(map, to, value)
    end
  end

  defp split_name(name) when is_binary(name) and name != "" do
    case String.split(name, " ", parts: 2) do
      [first, last] -> %{"first_name" => first, "last_name" => last}
      [first] -> %{"first_name" => first}
    end
  end

  defp split_name(_name), do: %{}

  defp non_empty([]), do: nil
  defp non_empty(""), do: nil
  defp non_empty(value), do: value

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
