defmodule Bazaar.Checkout do
  @moduledoc """
  The checkout session's protocol rules: what a request changes, and the
  document the spec expects back.

  A handler keeps a small state per checkout (what the platform asked for)
  and rebuilds the response from it on every call, so prices, stock,
  fulfillment options and discounts always come from the business and never
  from the request. This module owns the protocol half of that: merging
  updates with the spec's carry-over rules, normalizing destinations,
  totals, discount allocations, status, the `ucp` envelope. The business
  half arrives as functions in `build/2`.

      state = Bazaar.Checkout.new(params, stored_addresses: &Shop.addresses/1)
      Bazaar.Checkout.build(state, item: &Shop.item/1, fulfillment_options: &Shop.rates/2, ...)

  ## State

  A plain map the handler may extend with keys of its own:

    * `id`, `currency` (default `"USD"`), `status` (`:open`, `:canceled` or
      `:completed`, the handler moves it), `order_id` (set by the handler on
      completion)
    * `line_items`: `[%{id, product_id, quantity}]`
    * `buyer`: as sent, consent normalized to the spec's purpose map
      (`Bazaar.BuyerConsent`); `consent_dialect` remembers which shape the
      platform spoke so the response answers in kind
    * `methods`: fulfillment methods with their destinations and groups, or
      `nil` before the platform sent any
    * `discount_codes`, `instruments`

  ## Update rules

  Only keys present in a request change. A method keeps its earlier
  `line_item_ids`, destinations and groups when the update omits them; a
  method without groups gets one consolidating group over its line items.
  Destinations are normalized to the spec's postal fields (the aliases
  `street`, `locality`/`city`, `region`/`state` and `country` some platforms
  send are accepted), a buyer's stored addresses are injected when a method
  carries none, and a destination whose content matches a stored address
  takes over the stored id, so resubmissions land on the same destination.
  """

  alias Bazaar.BuyerConsent

  @address_fields ~w(street_address address_locality address_region postal_code address_country)

  # Currency

  @doc """
  Converts an amount in major units (dollars) to minor units (cents).

      iex> Bazaar.Checkout.to_minor_units(19.99)
      1999
  """
  def to_minor_units(amount) when is_float(amount), do: round(amount * 100)
  def to_minor_units(amount) when is_integer(amount), do: amount * 100

  def to_minor_units(%Decimal{} = amount) do
    amount |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_integer()
  end

  @doc """
  Converts an amount in minor units (cents) to major units (dollars).

      iex> Bazaar.Checkout.to_major_units(1999)
      19.99
  """
  def to_major_units(amount) when is_integer(amount), do: amount / 100

  # State

  @doc """
  The state for a create request. Options are those of `apply_update/3`.
  """
  def new(params, opts \\ []) do
    %{
      id: present(params["id"]) || "chk_" <> random_id(),
      currency: params["currency"] || "USD",
      status: :open,
      line_items: [],
      buyer: nil,
      consent_dialect: nil,
      methods: nil,
      discount_codes: [],
      instruments: [],
      order_id: nil
    }
    |> apply_update(params, opts)
  end

  @doc """
  Merges an update request into the state (see the update rules above).

  Options:

    * `:stored_addresses`: `fn buyer -> [address] end`, the addresses the
      business knows for a buyer, injected into methods that carry none
      (default: none)
  """
  def apply_update(state, params, opts \\ []) do
    state
    |> update_line_items(params["line_items"])
    |> update_buyer(params["buyer"])
    |> update_methods(get_in(params, ["fulfillment", "methods"]), opts)
    |> update_discounts(params["discounts"])
    |> update_instruments(get_in(params, ["payment", "instruments"]))
  end

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

  defp update_methods(state, nil, _opts), do: state

  defp update_methods(state, methods, opts) when is_list(methods) do
    previous = state.methods || []
    all_line_ids = Enum.map(state.line_items, & &1.id)
    stored = stored_addresses(state.buyer, opts)

    normalized =
      methods
      |> Enum.with_index(1)
      |> Enum.map(fn {method, index} ->
        id = present(method["id"]) || "method_#{index}"
        earlier = Enum.find(previous, &(&1.id == id))
        type = method["type"] || (earlier && earlier.type) || "shipping"

        line_item_ids =
          method["line_item_ids"] || (earlier && earlier.line_item_ids) || all_line_ids

        {destinations, id_map} =
          resolve_destinations(method["destinations"], earlier, stored, type)

        selected =
          case present(method["selected_destination_id"]) do
            nil -> nil
            client_id -> Map.get(id_map, client_id, client_id)
          end

        %{
          id: id,
          type: type,
          line_item_ids: line_item_ids,
          destinations: destinations,
          selected_destination_id: selected,
          groups: resolve_groups(method["groups"], earlier, line_item_ids)
        }
      end)

    %{state | methods: normalized}
  end

  defp stored_addresses(buyer, opts) do
    case Keyword.get(opts, :stored_addresses) do
      nil -> []
      fun -> fun.(buyer) || []
    end
  end

  defp resolve_destinations(provided, earlier, stored, type) do
    case provided do
      list when is_list(list) and list != [] ->
        Enum.map_reduce(list, %{}, fn raw, id_map ->
          dest = normalize_destination(raw, type)
          client_id = dest["id"]

          case Enum.find(stored, &same_address?(&1, dest)) do
            %{"id" => stored_id} = match ->
              {Map.put_new(match, "type", dest["type"]),
               if(client_id, do: Map.put(id_map, client_id, stored_id), else: id_map)}

            nil ->
              {Map.put(dest, "id", client_id || "dest_" <> random_id()), id_map}
          end
        end)

      _ ->
        cond do
          stored != [] ->
            {Enum.map(stored, &Map.put_new(&1, "type", destination_type(type))), %{}}

          earlier ->
            {earlier.destinations, %{}}

          true ->
            {[], %{}}
        end
    end
  end

  defp normalize_destination(raw, type) do
    %{
      "type" => raw["type"] || destination_type(type),
      "id" => present(raw["id"]),
      "street_address" => raw["street_address"] || raw["street"],
      "address_locality" => raw["address_locality"] || raw["locality"] || raw["city"],
      "address_region" => raw["address_region"] || raw["region"] || raw["state"],
      "postal_code" => raw["postal_code"],
      "address_country" => raw["address_country"] || raw["country"]
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp destination_type("pickup"), do: "business_location"
  defp destination_type(_shipping), do: "shipping_address"

  defp same_address?(stored, dest) do
    Enum.all?(@address_fields, &(Map.get(stored, &1) == Map.get(dest, &1)))
  end

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

  # Document

  @doc """
  The checkout document for a state. The business supplies:

    * `:item` (required): `fn product_id -> %{item: item, stock: n} | nil end`.
      `item` is the spec's item (`title`, `price`, optional `image_url`; the
      id is filled in). `nil` drops the line with a `not_found` error,
      `stock: 0` with `out_of_stock`, a quantity above stock is clamped with a
      `quantity_adjusted` warning, `stock: nil` means unlimited.
    * `:fulfillment_options`: `fn destination, context -> [option] end`, the
      options for a method whose destination is selected; `context` carries
      `method`, the priced `line_items` and the `subtotal`. Options are the
      spec's (`id`, `title`, `totals` with a `total`).
    * `:discount`: `fn code, running_total -> %{"code", "title", "amount"} | nil end`.
      Codes apply in order on the running total (items plus fulfillment), so a
      second percentage discounts the already reduced amount; the library adds
      the `allocations` and the negative `discount` totals entries. `nil`
      drops the code silently.
    * `:payment_handlers`: the `ucp.payment_handlers` registry to advertise
    * `:links`: the legal links (privacy policy, terms), mandatory in the spec
    * `:order_url`: `fn order_id -> url end`, the permalink for a completed
      checkout's order (required once `state.order_id` is set)
    * `:messages`: extra messages appended to what pricing found

  Status is `canceled` or `completed` from the state, `incomplete` while an
  error message exists or a fulfillment method lacks a destination or option,
  and `ready_for_complete` otherwise.
  """
  def build(state, opts) do
    item = Keyword.fetch!(opts, :item)
    {line_docs, line_messages} = price_line_items(state.line_items, item)
    subtotal = line_docs |> Enum.map(&line_total/1) |> Enum.sum()

    context = %{line_items: line_docs, subtotal: subtotal}

    {method_docs, fulfillment_amount} =
      build_methods(state.methods, Keyword.get(opts, :fulfillment_options), context)

    {applied, discount_entries} =
      apply_discounts(
        state.discount_codes,
        subtotal + fulfillment_amount,
        Keyword.get(opts, :discount)
      )

    total = subtotal + fulfillment_amount - Enum.sum(Enum.map(applied, & &1["amount"]))

    totals =
      [%{"type" => "subtotal", "amount" => subtotal}] ++
        fulfillment_entry(state.methods, fulfillment_amount) ++
        discount_entries ++ [%{"type" => "total", "amount" => total}]

    messages = line_messages ++ Keyword.get(opts, :messages, [])
    version = Bazaar.DiscoveryProfile.version()

    ucp =
      %{
        "version" => version,
        "capabilities" => %{"dev.ucp.shopping.checkout" => [%{"version" => version}]}
      }
      |> put_unless_nil("payment_handlers", Keyword.get(opts, :payment_handlers))

    %{
      "ucp" => ucp,
      "id" => state.id,
      "status" => status(state, messages, method_docs),
      "currency" => state.currency,
      "line_items" => line_docs,
      "totals" => totals,
      "links" => Keyword.get(opts, :links, []),
      "payment" => %{"instruments" => state.instruments},
      "messages" => messages
    }
    |> put_unless_nil("buyer", buyer_doc(state))
    |> put_unless_nil("fulfillment", method_docs && %{"methods" => method_docs})
    |> put_unless_nil("discounts", discounts_doc(state.discount_codes, applied))
    |> put_unless_nil("order", order_ref(state, Keyword.get(opts, :order_url)))
  end

  defp status(%{status: :canceled}, _messages, _methods), do: "canceled"
  defp status(%{status: :completed}, _messages, _methods), do: "completed"

  defp status(_state, messages, methods) do
    errors? = Enum.any?(messages, &(&1["type"] == "error"))

    unready? =
      methods != nil and not fulfillment_ready?(%{"fulfillment" => %{"methods" => methods}})

    if errors? or unready?, do: "incomplete", else: "ready_for_complete"
  end

  defp buyer_doc(%{buyer: nil}), do: nil

  defp buyer_doc(%{buyer: buyer, consent_dialect: :legacy}),
    do: Map.update!(buyer, "consent", &BuyerConsent.legacy/1)

  defp buyer_doc(%{buyer: buyer}), do: buyer

  defp order_ref(%{order_id: id}, order_url) when is_binary(id) do
    unless order_url, do: raise(ArgumentError, "build/2 needs :order_url once an order exists")
    %{"id" => id, "permalink_url" => order_url.(id)}
  end

  defp order_ref(_state, _order_url), do: nil

  # Line items

  defp price_line_items(line_items, item) do
    line_items
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {line, index}, {docs, messages} ->
      path = "$.line_items[#{index}]"

      case item.(line.product_id) do
        nil ->
          {docs, messages ++ [error("not_found", "Item #{line.product_id} was not found", path)]}

        %{stock: 0} ->
          {docs,
           messages ++ [error("out_of_stock", "Item #{line.product_id} is out of stock", path)]}

        %{item: item} = found ->
          {quantity, warnings} =
            clamp_quantity(line.quantity, Map.get(found, :stock), line.product_id, path)

          amount = item["price"] * quantity

          doc = %{
            "id" => line.id,
            "item" => Map.put(item, "id", line.product_id),
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

  defp clamp_quantity(quantity, stock, product_id, path)
       when is_integer(stock) and quantity > stock do
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

  defp line_total(line), do: line["totals"] |> hd() |> Map.fetch!("amount")

  # Fulfillment

  defp build_methods(nil, _options_fun, _context), do: {nil, 0}

  defp build_methods(methods, options_fun, context) do
    Enum.map_reduce(methods, 0, fn method, amount ->
      selected = Enum.find(method.destinations, &(&1["id"] == method.selected_destination_id))

      options =
        if selected && options_fun, do: options_fun.(selected, Map.put(context, :method, method))

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

  defp option_amount(nil), do: 0

  defp option_amount(option) do
    Enum.find_value(option["totals"] || [], 0, &(&1["type"] == "total" && &1["amount"]))
  end

  defp fulfillment_entry(methods, amount) do
    if methods && Enum.any?(methods, fn m -> Enum.any?(m.groups, & &1.selected_option_id) end),
      do: [%{"type" => "fulfillment", "amount" => amount}],
      else: []
  end

  @doc "True when every fulfillment method has a destination and an option selected."
  def fulfillment_ready?(%{"fulfillment" => %{"methods" => [_ | _] = methods}}) do
    Enum.all?(methods, fn method ->
      Map.has_key?(method, "selected_destination_id") and
        Enum.all?(method["groups"], &Map.has_key?(&1, "selected_option_id"))
    end)
  end

  def fulfillment_ready?(_doc), do: false

  # Discounts

  defp apply_discounts(codes, base, discount_fun) do
    {applied, _running} =
      Enum.reduce(codes, {[], base}, fn code, {applied, running} ->
        case discount_fun && discount_fun.(code, running) do
          %{"amount" => amount} = discount ->
            entry =
              Map.put(discount, "allocations", [%{"path" => "$.totals", "amount" => amount}])

            {applied ++ [entry], running - amount}

          _ ->
            {applied, running}
        end
      end)

    entries =
      for %{"amount" => amount} <- applied, amount > 0 do
        %{"type" => "discount", "amount" => -amount}
      end

    {applied, entries}
  end

  defp discounts_doc([], []), do: nil
  defp discounts_doc(codes, []), do: %{"codes" => codes}
  defp discounts_doc(codes, applied), do: %{"codes" => codes, "applied" => applied}

  # Messages

  @doc "An error message that asks the buyer for input, optionally at a JSONPath."
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

  defp random_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
