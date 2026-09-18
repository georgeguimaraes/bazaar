defmodule FlowerShop.Checkout do
  @moduledoc """
  The flower shop's side of `Bazaar.Checkout`: what an item costs and how
  many are in stock, the shipping rates for a destination, what a discount
  code is worth, the shop's legal links and payment handler. The protocol
  rules (update merging, totals, status, envelope) are the library's.

  Every response is rebuilt from the stored state with `build/2`, so pricing,
  stock checks, shipping options and discounts are recomputed from the
  catalog and never trusted from the request.
  """

  alias Bazaar.Checkout
  alias FlowerShop.Catalog

  @doc "The state for a create request, remembering the shop's URL and the platform's profile."
  def new(params, opts) do
    params
    |> Checkout.new(stored_addresses: &stored_addresses/1)
    |> Map.merge(%{
      profile_url: Keyword.get(opts, :profile_url),
      base_url: Keyword.fetch!(opts, :base_url)
    })
  end

  def apply_update(state, params, opts \\ []) do
    state
    |> maybe_put(:profile_url, Keyword.get(opts, :profile_url))
    |> Checkout.apply_update(params, stored_addresses: &stored_addresses/1)
  end

  @doc "The checkout document for the state, with any extra messages appended."
  def build(state, opts \\ []) do
    Checkout.build(state,
      item: &item/1,
      fulfillment_options: &shipping_options/2,
      discount: &discount/2,
      payment_handlers: payment_handlers(),
      links: [
        %{"type" => "privacy_policy", "url" => state.base_url <> "/privacy"},
        %{"type" => "terms_of_service", "url" => state.base_url <> "/terms"}
      ],
      order_url: &(state.base_url <> "/orders/" <> &1),
      loyalty: &loyalty/1,
      payment_terms: fn %{total: total} -> Catalog.payment_terms(total) end,
      messages: unknown_claims(state) ++ Keyword.get(opts, :messages, [])
    )
  end

  # The program's claim gets a membership; a claim the shop doesn't run is
  # reported, as the loyalty extension asks, with a recoverable error.
  defp loyalty(%{state: state, subtotal: subtotal}) do
    if Catalog.loyalty_program() in Checkout.eligibility(state),
      do: %{
        Catalog.loyalty_program() =>
          Catalog.membership(state.buyer && state.buyer["email"], subtotal)
      },
      else: nil
  end

  defp unknown_claims(state) do
    for claim <- Checkout.eligibility(state), claim != Catalog.loyalty_program() do
      %{
        "type" => "error",
        "code" => "eligibility_invalid",
        "content" => "#{claim} is not a program this shop runs",
        "severity" => "recoverable",
        "path" => "$.context.eligibility"
      }
    end
  end

  @doc "A known customer's stored addresses, by email."
  def stored_addresses(buyer), do: Catalog.customer_addresses(buyer && buyer["email"])

  @doc "A catalog product as a checkout item with its stock, `nil` when unknown."
  def item(product_id) do
    case Catalog.product(product_id) do
      nil ->
        nil

      product ->
        %{
          item: %{
            "title" => product.title,
            "price" => product.price,
            "image_url" => product.image_url
          },
          stock: product.stock
        }
    end
  end

  # Rates depend on the destination country; standard shipping is free on
  # orders with roses or over the free-shipping threshold.
  defp shipping_options(%{"address_country" => country}, %{line_items: lines, subtotal: subtotal}) do
    free? = Catalog.free_shipping?(subtotal, Enum.map(lines, & &1["item"]["id"]))

    country
    |> Catalog.shipping_options(free_shipping: free?)
    |> Enum.map(fn rate ->
      %{
        "id" => rate.id,
        "title" => rate.title,
        "totals" => [%{"type" => "total", "amount" => rate.price}]
      }
    end)
  end

  defp shipping_options(_destination, _context), do: nil

  @doc "What a discount code is worth on a running total, `nil` for an unknown code."
  def discount(code, running) do
    case Catalog.discount(code) do
      nil ->
        nil

      discount ->
        %{
          "code" => Catalog.canonical_discount_code(code),
          "title" => discount.title,
          "amount" => discount_amount(discount, running)
        }
    end
  end

  defp discount_amount(%{type: :percentage, value: pct}, running), do: div(running * pct, 100)
  defp discount_amount(%{type: :fixed_amount, value: value}, running), do: min(value, running)

  defp payment_handlers do
    handler = Catalog.payment_handler()

    %{
      handler.namespace => [%{"id" => handler.id, "version" => Bazaar.DiscoveryProfile.version()}]
    }
  end

  defp maybe_put(state, _key, nil), do: state
  defp maybe_put(state, key, value), do: Map.put(state, key, value)

  def uuid do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)

    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [a, b, c, d, e])
    |> to_string()
  end
end
