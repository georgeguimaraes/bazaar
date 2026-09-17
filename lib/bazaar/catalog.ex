defmodule Bazaar.Catalog do
  @moduledoc """
  The rules every catalog handler would otherwise reimplement, as pure
  functions over product documents in the spec's shape (string-keyed maps
  with `id`, `title`, `description`, `price_range` and `variants`).

  A handler with its products in a list gets the spec's semantics with a
  few calls:

      def search_products(params, _conn) do
        products =
          Shop.products()
          |> Enum.filter(&matches?(&1, params["query"]))
          |> Bazaar.Catalog.filter(params["filters"])

        {page, pagination} = Bazaar.Catalog.paginate(products, params["pagination"])
        {:ok, %{"products" => page, "pagination" => pagination}}
      end

      def lookup_products(%{"ids" => ids}, _conn) do
        {products, _unknown} = Bazaar.Catalog.lookup(Shop.products(), ids)
        {:ok, %{"products" => products}}
      end

      def get_product(%{"id" => id} = params, _conn) do
        case Bazaar.Catalog.find(Shop.products(), id) do
          nil -> {:error, :not_found}
          product -> {:ok, %{"product" => Bazaar.Catalog.detail_product(product, params["selected"])}}
        end
      end

  Variants are the purchasable unit: a variant's `id` is what checkout
  receives as `item.id`, and every id-based operation here resolves both
  product and variant ids, as the spec requires.
  """

  @default_limit 10

  @doc """
  Adds the `ucp` metadata a catalog response carries: the version and the
  capability that answered (`dev.ucp.shopping.catalog.search` for search,
  `dev.ucp.shopping.catalog.lookup` for lookup and get product). A document
  that already has a `ucp` key is left alone.
  """
  def envelope(%{"ucp" => _} = document, _operation), do: document

  def envelope(document, operation) when operation in [:search, :lookup] do
    version = Bazaar.DiscoveryProfile.version()

    Map.put(document, "ucp", %{
      "version" => version,
      "capabilities" => %{
        "dev.ucp.shopping.catalog.#{operation}" => [%{"version" => version}]
      }
    })
  end

  @doc """
  Applies the spec's search filters, which combine with AND:

    * `categories`: a product stays when any of its categories, or any of
      its variants' categories, is in the list
    * `price`: `min` and `max` in minor units, matched against each
      variant's price; variants outside the range are dropped, and a
      product with no variant left is dropped with them

  Unknown filter keys are ignored, and `nil` filters return the products.
  """
  def filter(products, nil), do: products

  def filter(products, filters) when is_map(filters) do
    products
    |> Enum.filter(&category_match?(&1, filters["categories"]))
    |> Enum.map(&price_filter(&1, filters["price"]))
    |> Enum.reject(&(&1["variants"] == []))
  end

  defp category_match?(_product, nil), do: true
  defp category_match?(_product, []), do: true

  defp category_match?(product, categories) when is_list(categories) do
    product_categories =
      Enum.flat_map([product | product["variants"] || []], &(&1["categories"] || []))

    Enum.any?(product_categories, &(&1["value"] in categories))
  end

  defp price_filter(product, nil), do: product

  defp price_filter(product, price) when is_map(price) do
    min = price["min"] || 0
    max = price["max"]

    variants =
      Enum.filter(product["variants"] || [], fn variant ->
        amount = get_in(variant, ["price", "amount"])
        is_integer(amount) and amount >= min and (is_nil(max) or amount <= max)
      end)

    Map.put(product, "variants", variants)
  end

  @doc """
  Pages a list the way the spec's `pagination` request asks: `limit`
  (default 10) and an opaque `cursor` from a previous response. Returns the
  page and the response's `pagination` object, with `cursor` present when
  there is a next page. A cursor this module did not issue starts over.
  """
  def paginate(products, pagination) do
    pagination = pagination || %{}
    limit = page_limit(pagination["limit"])
    offset = decode_cursor(pagination["cursor"])
    total = length(products)

    page = products |> Enum.drop(offset) |> Enum.take(limit)
    has_next_page = offset + limit < total

    response = %{"has_next_page" => has_next_page, "total_count" => total}

    response =
      if has_next_page,
        do: Map.put(response, "cursor", encode_cursor(offset + limit)),
        else: response

    {page, response}
  end

  defp page_limit(limit) when is_integer(limit) and limit > 0, do: limit
  defp page_limit(_), do: @default_limit

  defp encode_cursor(offset), do: Base.url_encode64("offset:#{offset}", padding: false)

  defp decode_cursor(cursor) when is_binary(cursor) do
    with {:ok, "offset:" <> offset} <- Base.url_decode64(cursor, padding: false),
         {offset, ""} when offset >= 0 <- Integer.parse(offset) do
      offset
    else
      _ -> 0
    end
  end

  defp decode_cursor(_), do: 0

  @doc """
  Resolves lookup ids to products for a lookup response. Each variant kept
  carries `inputs`, the request ids that resolved to it: a variant id or SKU
  matches that variant exactly, a product id resolves to the product's
  featured (first) variant. Variants no id reached are dropped, as are
  products with none left. Returns the products and the ids nothing matched.
  """
  def lookup(products, ids) when is_list(ids) do
    products =
      products
      |> Enum.map(&correlate(&1, ids))
      |> Enum.reject(&(&1["variants"] == []))

    resolved =
      for product <- products,
          variant <- product["variants"],
          input <- variant["inputs"],
          into: MapSet.new(),
          do: input["id"]

    {products, Enum.reject(ids, &MapSet.member?(resolved, &1))}
  end

  defp correlate(product, ids) do
    variants =
      product["variants"]
      |> Enum.with_index()
      |> Enum.map(fn {variant, index} ->
        exact = for id <- ids, id in [variant["id"], variant["sku"]], do: input(id, "exact")

        # A product id lands on the featured variant, unless that variant
        # already matched it exactly (single-variant products often share the id).
        featured =
          if index == 0 and product["id"] in ids and
               product["id"] not in [variant["id"], variant["sku"]],
             do: [input(product["id"], "featured")],
             else: []

        Map.put(variant, "inputs", exact ++ featured)
      end)
      |> Enum.reject(&(&1["inputs"] == []))

    Map.put(product, "variants", variants)
  end

  defp input(id, match), do: %{"id" => id, "match" => match}

  @doc "The product with this id, or the product owning the variant with this id."
  def find(products, id) when is_binary(id) do
    Enum.find(products, fn product ->
      product["id"] == id or Enum.any?(product["variants"] || [], &(&1["id"] == id))
    end)
  end

  def find(_products, _id), do: nil

  @doc """
  Shapes a product for a get product response: option values gain
  `available` and `exists`, relative to the effective selections, and the
  variant those selections anchor moves to the front as the featured one.

  `selected` is the request's list of `%{"name", "label", "id"?}`. When no
  variant matches every selection, selections are relaxed from the end of
  `:preferences` (option names, most important first) or, without
  preferences, from the last selection given, until one does. A product
  without options is returned unchanged.
  """
  def detail_product(product, selected, opts \\ [])

  def detail_product(
        %{"options" => [_ | _] = options, "variants" => [_ | _] = variants} = product,
        selected,
        opts
      ) do
    selected = effective_selection(variants, selected || [], Keyword.get(opts, :preferences))

    options =
      Enum.map(options, fn option ->
        values =
          Enum.map(option["values"], fn value ->
            selections = replace_selection(selected, option["name"], value)
            matching = Enum.filter(variants, &variant_matches?(&1, selections))

            Map.merge(value, %{
              "exists" => matching != [],
              "available" => Enum.any?(matching, &available?/1)
            })
          end)

        Map.put(option, "values", values)
      end)

    featured = Enum.find(variants, &variant_matches?(&1, selected))

    product
    |> Map.merge(%{"options" => options, "selected" => selected})
    |> Map.put("variants", [featured | List.delete(variants, featured)])
  end

  def detail_product(product, _selected, _opts), do: product

  defp effective_selection(variants, selected, preferences) do
    if Enum.any?(variants, &variant_matches?(&1, selected)) do
      selected
    else
      effective_selection(variants, relax(selected, preferences), preferences)
    end
  end

  # Drops the least preferred selection: the last name in preferences that is
  # still selected, or the last selection when there are no preferences.
  defp relax(selected, preferences) when is_list(preferences) do
    case Enum.reverse(preferences) |> Enum.find(fn name -> selection_for(selected, name) end) do
      nil -> relax(selected, nil)
      name -> Enum.reject(selected, &(&1["name"] == name))
    end
  end

  defp relax(selected, _preferences), do: Enum.drop(selected, -1)

  defp selection_for(selected, name), do: Enum.find(selected, &(&1["name"] == name))

  defp replace_selection(selected, name, value) do
    Enum.reject(selected, &(&1["name"] == name)) ++ [Map.put(value, "name", name)]
  end

  defp variant_matches?(variant, selections) do
    options = variant["options"] || []
    Enum.all?(selections, fn selection -> Enum.any?(options, &same_option?(&1, selection)) end)
  end

  # Ids win when both sides carry one; labels otherwise, as the spec asks.
  defp same_option?(option, selection) do
    option["name"] == selection["name"] and
      if option["id"] && selection["id"],
        do: option["id"] == selection["id"],
        else: option["label"] == selection["label"]
  end

  defp available?(variant), do: get_in(variant, ["availability", "available"]) != false
end
