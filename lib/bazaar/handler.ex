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
          :checkout | :orders | :identity | :fulfillment | :discount | :buyer_consent | :catalog

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
  @callback complete_checkout(id(), conn()) ::
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
    complete_checkout: 2,
    cancel_checkout: 2,
    # Orders
    get_order: 2,
    update_order: 3,
    cancel_order: 2,
    # Catalog
    search_products: 2,
    lookup_products: 2,
    get_product: 2,
    # Identity
    link_identity: 2,
    # Webhooks
    handle_webhook: 1
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour Bazaar.Handler

      # Default implementations
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
    end
  end
end
