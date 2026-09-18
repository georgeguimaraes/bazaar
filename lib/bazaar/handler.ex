defmodule Bazaar.Handler do
  @moduledoc """
  Behaviour for implementing UCP merchant handlers.

  Implement this behaviour to define your commerce logic. The callbacks
  correspond to UCP capabilities (checkout, orders, identity).

  ## Example

      defmodule MyApp.Commerce.Handler do
        use Bazaar.Handler

        @impl Bazaar.Handler
        def capabilities, do: [:checkout, :orders]

        @impl Bazaar.Handler
        def create_checkout(params, conn) do
          case MyApp.Checkouts.create(params) do
            {:ok, checkout} -> {:ok, checkout}
            {:error, changeset} -> {:error, changeset}
          end
        end

        @impl Bazaar.Handler
        def get_checkout(id, _conn) do
          case MyApp.Checkouts.get(id) do
            nil -> {:error, :not_found}
            checkout -> {:ok, checkout}
          end
        end
      end

  ## Required Callbacks

  Depending on which capabilities you declare, you must implement
  the corresponding callbacks:

  ### Checkout Capability
  - `create_checkout/2` - Create a new checkout session
  - `get_checkout/2` - Retrieve a checkout session
  - `update_checkout/3` - Update a checkout session
  - `complete_checkout/2` - Complete a checkout session and create an order
  - `cancel_checkout/2` - Cancel a checkout session

  ### Orders Capability
  - `get_order/2` - Retrieve an order
  - `cancel_order/2` - Cancel an order

  ### Cart Capability
  - `create_cart/2`, `get_cart/2`, `update_cart/3`, `cancel_cart/2` - Carts
    before checkout, built with `Bazaar.Cart`. With this capability a
    platform may create a checkout from a cart: `create_checkout/2` then
    receives `cart_id`, must build the checkout from the cart's line items,
    buyer and context (`Bazaar.Checkout.from_cart/3`) and must answer with
    the existing checkout when one was already created for that cart.

  ### Location Capability
  - `search_locations/2` - Find stores by `query`, `distance`, `serves`,
    `filters` (amenities, hours, items) and `pagination`
  - `lookup_locations/2` - Resolve a list of location `ids`

  Both take the request body and return `{:ok, %{"locations" => [...], ...}}`
  without the `ucp` metadata; `Bazaar.Location` has the distance, hours,
  amenity and lookup rules.

  ### Loyalty and Payment Terms (extensions)
  No callbacks: `:loyalty` and `:payment_terms` advertise the extensions and
  the checkout builder answers them through its `:loyalty` and
  `:payment_terms` options (see `Bazaar.Checkout.build/2`).

  ### Catalog Capability
  - `search_products/2` - Search by `query`, `filters` and `pagination`
  - `lookup_products/2` - Resolve a list of product or variant `ids`
  - `get_product/2` - One product by `id`, with option `selected` narrowing

  Catalog callbacks take the request body and return the response document
  without its `ucp` metadata, which the controller adds:

      {:ok, %{"products" => [...], "pagination" => %{"has_next_page" => false}}}
      {:ok, %{"products" => [...]}}
      {:ok, %{"product" => %{...}}} | {:error, :not_found}

  `Bazaar.Catalog` has the filtering, pagination, id resolution and option
  availability rules the spec asks of every implementation.

  ### Identity Capability
  - `link_identity/2` - Link a user identity via OAuth
  """

  @type conn :: Plug.Conn.t()
  @type params :: map()
  @type id :: String.t()
  @type capability ::
          :checkout
          | :orders
          | :identity
          | :fulfillment
          | :discount
          | :buyer_consent
          | :catalog
          | :cart
          | :location
          | :loyalty
          | :payment_terms

  # Discovery
  @callback capabilities() :: [capability()]
  @callback business_profile() :: map()

  # Fulfillment configuration (optional)
  @callback fulfillment_config() :: map()

  # Checkout capability
  @callback create_checkout(params(), conn()) ::
              {:ok, map()} | {:error, term()}
  @callback get_checkout(id(), conn()) ::
              {:ok, map()} | {:error, :not_found | term()}
  @callback update_checkout(id(), params(), conn()) ::
              {:ok, map()} | {:error, :not_found | term()}
  @callback complete_checkout(id(), params(), conn()) ::
              {:ok, map()} | {:error, :not_found | :invalid_state | term()}
  @callback cancel_checkout(id(), conn()) ::
              {:ok, map()} | {:error, :not_found | term()}

  # Orders capability
  @callback get_order(id(), conn()) ::
              {:ok, map()} | {:error, :not_found | term()}
  @callback update_order(id(), params(), conn()) ::
              {:ok, map()} | {:error, :not_found | term()}
  @callback cancel_order(id(), conn()) ::
              {:ok, map()} | {:error, :not_found | term()}

  # Cart capability
  @callback create_cart(params(), conn()) ::
              {:ok, map()} | {:error, term()}
  @callback get_cart(id(), conn()) ::
              {:ok, map()} | {:error, :not_found | term()}
  @callback update_cart(id(), params(), conn()) ::
              {:ok, map()} | {:error, :not_found | term()}
  @callback cancel_cart(id(), conn()) ::
              {:ok, map()} | {:error, :not_found | term()}

  # Location capability
  @callback search_locations(params(), conn()) ::
              {:ok, map()} | {:error, term()}
  @callback lookup_locations(params(), conn()) ::
              {:ok, map()} | {:error, term()}

  # Catalog capability
  @callback search_products(params(), conn()) ::
              {:ok, map()} | {:error, term()}
  @callback lookup_products(params(), conn()) ::
              {:ok, map()} | {:error, term()}
  @callback get_product(params(), conn()) ::
              {:ok, map()} | {:error, :not_found | term()}

  # Identity capability
  @callback link_identity(params(), conn()) ::
              {:ok, map()} | {:error, term()}

  # Webhooks
  @callback handle_webhook(map()) ::
              {:ok, term()} | {:error, term()}

  @optional_callbacks [
    # Discovery
    fulfillment_config: 0,
    # Checkout
    create_checkout: 2,
    get_checkout: 2,
    update_checkout: 3,
    complete_checkout: 3,
    cancel_checkout: 2,
    # Orders
    get_order: 2,
    update_order: 3,
    cancel_order: 2,
    # Cart
    create_cart: 2,
    get_cart: 2,
    update_cart: 3,
    cancel_cart: 2,
    # Location
    search_locations: 2,
    lookup_locations: 2,
    # Catalog
    search_products: 2,
    lookup_products: 2,
    get_product: 2,
    # Identity
    link_identity: 2,
    # Webhooks
    handle_webhook: 1
  ]

  @doc """
  Defines every capability's callbacks from `Bazaar.Handler.Defaults` over
  the `Bazaar.Shop` and `Bazaar.Store` given, all overridable: declare
  `capabilities/0` and `business_profile/0` and the store answers. Override
  a callback when a default doesn't fit; `Bazaar.Handler.Defaults` is
  there to call for the rest of it.

      defmodule MyApp.CommerceHandler do
        use Bazaar.Handler, shop: MyApp.Shop, store: Bazaar.Store.ETS

        @impl true
        def capabilities, do: [:checkout, :orders, :fulfillment]

        @impl true
        def business_profile, do: %{"name" => "My Store"}
      end
  """
  defmacro __using__(opts) do
    shop = Keyword.get(opts, :shop)
    store = Keyword.get(opts, :store)

    unless shop && store do
      raise ArgumentError,
            "use Bazaar.Handler needs a shop and a store: " <>
              "use Bazaar.Handler, shop: MyApp.Shop, store: Bazaar.Store.ETS"
    end

    quote do
      @behaviour Bazaar.Handler

      @impl Bazaar.Handler
      def capabilities, do: [:checkout]

      @impl Bazaar.Handler
      def business_profile do
        %{
          "name" => "My Store",
          "description" => "A UCP-enabled store"
        }
      end

      @impl Bazaar.Handler
      def fulfillment_config do
        Bazaar.Fulfillment.default_merchant_config()
      end

      defoverridable capabilities: 0, business_profile: 0, fulfillment_config: 0

      unquote(Bazaar.Handler.defaults(shop, store))
    end
  end

  @doc false
  def defaults(shop, store) do
    quote do
      @doc false
      def __bazaar__(:shop), do: unquote(shop)
      def __bazaar__(:store), do: unquote(store)

      alias Bazaar.Handler.Defaults

      @impl Bazaar.Handler
      def create_checkout(params, conn), do: Defaults.create_checkout(__MODULE__, params, conn)
      @impl Bazaar.Handler
      def get_checkout(id, conn), do: Defaults.get_checkout(__MODULE__, id, conn)
      @impl Bazaar.Handler
      def update_checkout(id, params, conn),
        do: Defaults.update_checkout(__MODULE__, id, params, conn)

      @impl Bazaar.Handler
      def complete_checkout(id, params, conn),
        do: Defaults.complete_checkout(__MODULE__, id, params, conn)

      @impl Bazaar.Handler
      def cancel_checkout(id, conn), do: Defaults.cancel_checkout(__MODULE__, id, conn)

      @impl Bazaar.Handler
      def create_cart(params, conn), do: Defaults.create_cart(__MODULE__, params, conn)
      @impl Bazaar.Handler
      def get_cart(id, conn), do: Defaults.get_cart(__MODULE__, id, conn)
      @impl Bazaar.Handler
      def update_cart(id, params, conn), do: Defaults.update_cart(__MODULE__, id, params, conn)
      @impl Bazaar.Handler
      def cancel_cart(id, conn), do: Defaults.cancel_cart(__MODULE__, id, conn)

      @impl Bazaar.Handler
      def get_order(id, conn), do: Defaults.get_order(__MODULE__, id, conn)
      @impl Bazaar.Handler
      def update_order(id, params, conn), do: Defaults.update_order(__MODULE__, id, params, conn)
      @impl Bazaar.Handler
      def cancel_order(id, conn), do: Defaults.cancel_order(__MODULE__, id, conn)

      @impl Bazaar.Handler
      def search_products(params, conn), do: Defaults.search_products(__MODULE__, params, conn)
      @impl Bazaar.Handler
      def lookup_products(params, conn), do: Defaults.lookup_products(__MODULE__, params, conn)
      @impl Bazaar.Handler
      def get_product(params, conn), do: Defaults.get_product(__MODULE__, params, conn)

      @impl Bazaar.Handler
      def search_locations(params, conn), do: Defaults.search_locations(__MODULE__, params, conn)
      @impl Bazaar.Handler
      def lookup_locations(params, conn), do: Defaults.lookup_locations(__MODULE__, params, conn)

      defoverridable create_checkout: 2,
                     get_checkout: 2,
                     update_checkout: 3,
                     complete_checkout: 3,
                     cancel_checkout: 2,
                     create_cart: 2,
                     get_cart: 2,
                     update_cart: 3,
                     cancel_cart: 2,
                     get_order: 2,
                     update_order: 3,
                     cancel_order: 2,
                     search_products: 2,
                     lookup_products: 2,
                     get_product: 2,
                     search_locations: 2,
                     lookup_locations: 2
    end
  end
end
