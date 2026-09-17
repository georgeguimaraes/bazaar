defmodule FlowerShop.Checkout do
  @moduledoc """
  Checkout state and the UCP checkout document built from it.

  The store keeps a small normalized state per checkout (what the platform
  asked for: items, buyer, fulfillment methods, discount codes). Every response
  is rebuilt from that state with `build/2`, so pricing, stock checks, shipping
  options and discounts are always recomputed from the catalog and never
  trusted from the request.
  """

  alias Bazaar.BuyerConsent
  alias FlowerShop.Catalog

  @type state :: map()

  @doc "Builds the initial state for a create request."
  def new(params, opts) do
    %{
      id: present(params["id"]) || "chk_" <> uuid(),
      currency: params["currency"] || "USD",
      status: :open,
      line_items: [],
      buyer: nil,
      consent_dialect: nil,
      methods: nil,
      discount_codes: [],
      instruments: [],
      order_id: nil,
      profile_url: Keyword.get(opts, :profile_url),
      base_url: Keyword.fetch!(opts, :base_url)
    }
    |> apply_update(params, opts)
  end

  @doc """
  Merges an update request into the state. Only keys present in the request
  change; the platform echoes whole subtrees back, so absent keys keep their
  previous value.
  """
  def apply_update(state, params, opts \\ []) do
    state
    |> maybe_put(:profile_url, Keyword.get(opts, :profile_url))
    |> update_line_items(params["line_items"])
    |> update_buyer(params["buyer"])
    |> update_methods(get_in(params, ["fulfillment", "methods"]))
    |> update_discounts(params["discounts"])
    |> update_instruments(get_in(params, ["payment", "instruments"]))
  end

  defp maybe_put(state, _key, nil), do: state
  defp maybe_put(state, key, value), do: Map.put(state, key, value)

  defp update_line_items(state, nil), do: state

  defp update_line_items(state, items) when is_list(items) do
    line_items =
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, index} ->
        %{
          id: present(item["id"]) || "li_#{index}",
          product_id: get_in(item, ["item", "id"]),
          quantity: item["quantity"] || 1
        }
      end)

    %{state | line_items: line_items}
  end

  defp update_buyer(state, nil), do: state

  # Consent is stored as the spec's purpose map whichever shape it arrived in;
  # the dialect is remembered so the response speaks the platform's language.
  defp update_buyer(state, buyer) when is_map(buyer) do
    case buyer["consent"] do
      consent when is_map(consent) ->
        dialect = if BuyerConsent.legacy?(consent), do: :legacy, else: :purposes

        %{
          state
          | buyer: Map.put(buyer, "consent", BuyerConsent.normalize(consent)),
            consent_dialect: dialect
        }

      _ ->
        %{state | buyer: buyer}
    end
  end

  defp update_methods(state, nil), do: state

  defp update_methods(state, methods) when is_list(methods) do
    previous = state.methods || []
    all_line_ids = Enum.map(state.line_items, & &1.id)

    normalized =
      methods
      |> Enum.with_index(1)
      |> Enum.map(fn {method, index} ->
        id = present(method["id"]) || "method_#{index}"
        earlier = Enum.find(previous, &(&1.id == id))

        line_item_ids =
          method["line_item_ids"] || (earlier && earlier.line_item_ids) || all_line_ids

        {destinations, id_map} =
          resolve_destinations(method["destinations"], earlier, state.buyer)

        selected =
          case present(method["selected_destination_id"]) do
            nil -> nil
            client_id -> Map.get(id_map, client_id, client_id)
          end

        %{
          id: id,
          type: method["type"] || "shipping",
          line_item_ids: line_item_ids,
          destinations: destinations,
          selected_destination_id: selected,
          groups: resolve_groups(method["groups"], earlier, line_item_ids)
        }
      end)

    %{state | methods: normalized}
  end

  # Destinations come in several shapes. Keys are normalized to the UCP postal
  # address fields, stored addresses of a known buyer are injected when the
  # method carries none, and content matching a stored address takes over the
  # stored id so resubmissions land on the same destination.
  defp resolve_destinations(provided, earlier, buyer) do
    stored = Catalog.customer_addresses(buyer && buyer["email"]) || []

    case provided do
      list when is_list(list) and list != [] ->
        Enum.map_reduce(list, %{}, fn raw, id_map ->
          dest = normalize_destination(raw)
          client_id = dest["id"]

          case Enum.find(stored, &same_address?(&1, dest)) do
            %{"id" => stored_id} = match ->
              {match, if(client_id, do: Map.put(id_map, client_id, stored_id), else: id_map)}

            nil ->
              {Map.put(dest, "id", client_id || "dest_" <> uuid()), id_map}
          end
        end)

      _ ->
        cond do
          stored != [] -> {stored, %{}}
          earlier -> {earlier.destinations, %{}}
          true -> {[], %{}}
        end
    end
  end

  @address_fields ~w(street_address address_locality address_region postal_code address_country)

  defp normalize_destination(raw) do
    %{
      "id" => present(raw["id"]),
      "street_address" => raw["street_address"] || raw["street"],
      "address_locality" => raw["address_locality"] || raw["locality"] || raw["city"],
      "address_region" => raw["address_region"] || raw["region"] || raw["state"],
      "postal_code" => raw["postal_code"],
      "address_country" => raw["address_country"] || raw["country"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp same_address?(stored, dest) do
    Enum.all?(@address_fields, &(Map.get(stored, &1) == Map.get(dest, &1)))
  end

  # Client groups are kept as sent (ids included). Without groups the method
  # gets one consolidating group, keeping an earlier selection if there was one.
  defp resolve_groups(groups, earlier, line_item_ids) do
    case groups do
      list when is_list(list) and list != [] ->
        list
        |> Enum.with_index(1)
        |> Enum.map(fn {group, index} ->
          %{
            id: present(group["id"]) || "group_#{index}",
            line_item_ids: group["line_item_ids"] || line_item_ids,
            selected_option_id: present(group["selected_option_id"])
          }
        end)

      _ ->
        case earlier && earlier.groups do
          [_ | _] = kept -> Enum.map(kept, &%{&1 | line_item_ids: line_item_ids})
          _ -> [%{id: "group_1", line_item_ids: line_item_ids, selected_option_id: nil}]
        end
    end
  end

  defp update_discounts(state, nil), do: state

  defp update_discounts(state, discounts) when is_map(discounts) do
    codes = discounts["codes"] || []
    %{state | discount_codes: Enum.filter(codes, &is_binary/1)}
  end

  defp update_instruments(state, nil), do: state
  defp update_instruments(state, list) when is_list(list), do: %{state | instruments: list}

  @doc """
  Builds the checkout document for the current state. Extra messages (for
  example a declined payment) are appended to whatever the pricing pass found.
  """
  def build(state, opts \\ []) do
    {line_docs, line_messages} = price_line_items(state.line_items)

    subtotal =
      line_docs |> Enum.map(&(&1["totals"] |> hd() |> Map.fetch!("amount"))) |> Enum.sum()

    product_ids = Enum.map(line_docs, & &1["item"]["id"])
    free_shipping? = Catalog.free_shipping?(subtotal, product_ids)

    {method_docs, fulfillment_amount} = build_methods(state.methods, free_shipping?)

    {applied, discount_entries} =
      apply_discounts(state.discount_codes, subtotal + fulfillment_amount)

    version = Bazaar.DiscoveryProfile.version()

    totals =
      [%{"type" => "subtotal", "amount" => subtotal}] ++
        fulfillment_entry(state.methods, fulfillment_amount) ++
        discount_entries ++
        [
          %{
            "type" => "total",
            "amount" =>
              subtotal + fulfillment_amount - Enum.sum(Enum.map(applied, & &1["amount"]))
          }
        ]

    %{
      "ucp" => %{
        "version" => version,
        "capabilities" => %{"dev.ucp.shopping.checkout" => [%{"version" => version}]},
        "payment_handlers" => payment_handlers(version)
      },
      "id" => state.id,
      "status" => status(state),
      "currency" => state.currency,
      "line_items" => line_docs,
      "totals" => totals,
      "links" => [
        %{"type" => "privacy_policy", "url" => state.base_url <> "/privacy"},
        %{"type" => "terms_of_service", "url" => state.base_url <> "/terms"}
      ],
      "payment" => %{"instruments" => state.instruments},
      "messages" => line_messages ++ Keyword.get(opts, :messages, [])
    }
    |> put_unless_nil("buyer", buyer_doc(state))
    |> put_unless_nil("fulfillment", method_docs && %{"methods" => method_docs})
    |> put_unless_nil("discounts", discounts_doc(state.discount_codes, applied))
    |> put_unless_nil("order", order_ref(state))
  end

  defp buyer_doc(%{buyer: nil}), do: nil

  defp buyer_doc(%{buyer: buyer, consent_dialect: :legacy}) do
    Map.update!(buyer, "consent", &BuyerConsent.legacy/1)
  end

  defp buyer_doc(%{buyer: buyer}), do: buyer

  defp status(%{status: :canceled}), do: "canceled"
  defp status(%{status: :completed}), do: "completed"
  defp status(_), do: "ready_for_complete"

  defp order_ref(%{status: :completed, order_id: id, base_url: base}) when is_binary(id) do
    %{"id" => id, "permalink_url" => base <> "/orders/" <> id}
  end

  defp order_ref(_), do: nil

  def payment_handlers(version) do
    handler = Catalog.payment_handler()
    %{handler.namespace => [%{"id" => handler.id, "version" => version}]}
  end

  # Prices always come from the catalog. Unknown or sold-out products are
  # dropped from the checkout with an error message; quantities above stock are
  # clamped with a warning.
  defp price_line_items(line_items) do
    line_items
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {line, index}, {docs, messages} ->
      path = "$.line_items[#{index}]"

      case Catalog.product(line.product_id) do
        nil ->
          {docs, messages ++ [error("not_found", "Item #{line.product_id} was not found", path)]}

        %{stock: 0} ->
          {docs,
           messages ++ [error("out_of_stock", "Item #{line.product_id} is out of stock", path)]}

        product ->
          {quantity, warnings} =
            clamp_quantity(line.quantity, product.stock, line.product_id, path)

          amount = product.price * quantity

          doc = %{
            "id" => line.id,
            "item" => %{
              "id" => line.product_id,
              "title" => product.title,
              "price" => product.price,
              "image_url" => product.image_url
            },
            "quantity" => quantity,
            "totals" => [
              %{"type" => "subtotal", "amount" => amount},
              %{"type" => "total", "amount" => amount}
            ]
          }

          {docs ++ [doc], messages ++ warnings}
      end
    end)
  end

  defp clamp_quantity(quantity, stock, product_id, path) when quantity > stock do
    {stock,
     [
       %{
         "type" => "warning",
         "code" => "quantity_adjusted",
         "content" => "Only #{stock} of #{product_id} are in stock; quantity was reduced",
         "path" => path
       }
     ]}
  end

  defp clamp_quantity(quantity, _stock, _product_id, _path), do: {quantity, []}

  defp build_methods(nil, _free?), do: {nil, 0}

  defp build_methods(methods, free_shipping?) do
    Enum.map_reduce(methods, 0, fn method, amount ->
      selected = Enum.find(method.destinations, &(&1["id"] == method.selected_destination_id))

      options =
        case selected do
          %{"address_country" => country} ->
            country
            |> Catalog.shipping_options(free_shipping: free_shipping?)
            |> Enum.map(&option_doc/1)

          _ ->
            nil
        end

      {group_docs, method_amount} =
        Enum.map_reduce(method.groups, 0, fn group, acc ->
          option = options && Enum.find(options, &(&1["id"] == group.selected_option_id))

          doc =
            %{"id" => group.id, "line_item_ids" => group.line_item_ids}
            |> put_unless_nil("options", options)
            |> put_unless_nil("selected_option_id", option && option["id"])

          {doc, acc + option_amount(option)}
        end)

      doc =
        %{
          "id" => method.id,
          "type" => method.type,
          "line_item_ids" => method.line_item_ids,
          "destinations" => method.destinations,
          "groups" => group_docs
        }
        |> put_unless_nil("selected_destination_id", selected && selected["id"])

      {doc, amount + method_amount}
    end)
  end

  defp option_doc(rate) do
    %{
      "id" => rate.id,
      "title" => rate.title,
      "totals" => [%{"type" => "total", "amount" => rate.price}]
    }
  end

  defp option_amount(nil), do: 0
  defp option_amount(option), do: option["totals"] |> hd() |> Map.fetch!("amount")

  defp fulfillment_entry(methods, amount) do
    if methods && Enum.any?(methods, fn m -> Enum.any?(m.groups, & &1.selected_option_id) end) do
      [%{"type" => "fulfillment", "amount" => amount}]
    else
      []
    end
  end

  # Codes apply in order on the running total (items plus shipping), so a
  # second percentage code discounts the already reduced amount. Unknown codes
  # are dropped silently.
  defp apply_discounts(codes, base) do
    {applied, _running} =
      Enum.reduce(codes, {[], base}, fn code, {applied, running} ->
        case Catalog.discount(code) do
          nil ->
            {applied, running}

          discount ->
            amount = discount_amount(discount, running)
            canonical = Catalog.canonical_discount_code(code)

            entry = %{
              "code" => canonical,
              "title" => discount.title,
              "amount" => amount,
              "allocations" => [%{"path" => "$.totals", "amount" => amount}]
            }

            {applied ++ [entry], running - amount}
        end
      end)

    entries =
      for %{"amount" => amount} <- applied, amount > 0 do
        %{"type" => "discount", "amount" => -amount}
      end

    {applied, entries}
  end

  defp discount_amount(%{type: :percentage, value: pct}, running), do: div(running * pct, 100)
  defp discount_amount(%{type: :fixed_amount, value: value}, running), do: min(value, running)

  defp discounts_doc([], []), do: nil
  defp discounts_doc(codes, []), do: %{"codes" => codes}
  defp discounts_doc(codes, applied), do: %{"codes" => codes, "applied" => applied}

  @doc "True when every fulfillment method has a destination and an option selected."
  def fulfillment_ready?(%{"fulfillment" => %{"methods" => [_ | _] = methods}}) do
    Enum.all?(methods, fn method ->
      Map.has_key?(method, "selected_destination_id") and
        Enum.all?(method["groups"], &Map.has_key?(&1, "selected_option_id"))
    end)
  end

  def fulfillment_ready?(_doc), do: false

  def error(code, content, path \\ nil) do
    %{
      "type" => "error",
      "code" => code,
      "content" => content,
      "severity" => "requires_buyer_input"
    }
    |> put_unless_nil("path", path)
  end

  defp put_unless_nil(map, _key, nil), do: map
  defp put_unless_nil(map, key, value), do: Map.put(map, key, value)

  defp present(""), do: nil
  defp present(value) when is_binary(value), do: value
  defp present(_), do: nil

  def uuid do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)

    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [a, b, c, d, e])
    |> to_string()
  end
end
