defmodule Bazaar.Shop do
  @moduledoc """
  The business's facts, as a behaviour: what an item costs, how it ships,
  what a code is worth, where the stores are. `use Bazaar.Handler, shop:
  MyApp.Shop, store: MyApp.Store` then answers every UCP operation from
  them (see `Bazaar.Handler`).

      defmodule MyApp.Shop do
        use Bazaar.Shop

        @impl true
        def base_url, do: "https://shop.example"

        @impl true
        def item("roses"), do: %{item: %{"title" => "Roses", "price" => 3500}, stock: 12}
        def item(_id), do: nil

        @impl true
        def fulfillment_options(_destination, _context),
          do: [%{"id" => "standard", "title" => "Standard", "totals" => [%{"type" => "total", "amount" => 500}]}]
      end

  Only `base_url/0` and `item/1` are required; `use Bazaar.Shop` gives every
  other callback a default that means "not offered" (no discounts, no
  pickup, no loyalty, no terms, an empty catalog, no stores). The facts are
  pure functions taking exactly what `Bazaar.Checkout.build/2`,
  `Bazaar.Catalog` and `Bazaar.Location` document for the matching option.

  Two callbacks are the shop's connection to the outside: `http_client/0`,
  which defaults to Req when you have it, and `signing_key/0`. With both,
  order webhooks deliver themselves, signed, through `order_placed/2` and
  `order_updated/2`.
  """

  @type context :: map()

  @doc "The absolute URL the store is served at, for order permalinks and cart links."
  @callback base_url() :: String.t()

  @doc "A line item's title, price and stock (`stock: nil` unlimited), `nil` when unknown."
  @callback item(id :: String.t()) :: %{item: map(), stock: non_neg_integer() | nil} | nil

  @doc "The fulfillment options for a selected destination (a shipping address or a business location)."
  @callback fulfillment_options(destination :: map(), context()) :: [map()] | nil

  @doc "The stores a pickup method may be fulfilled at (`id`, `name`, `address`), `nil` when pickup is not offered."
  @callback pickup_locations(context()) :: [map()] | nil

  @doc "Addresses known for a buyer, injected into fulfillment methods that carry none."
  @callback stored_addresses(buyer :: map() | nil) :: [map()] | nil

  @doc "What a discount code is worth on the running total, `nil` for an unknown code."
  @callback discount(code :: String.t(), running_total :: integer()) :: map() | nil

  @doc "The `ucp.payment_handlers` registry advertised on checkouts."
  @callback payment_handlers() :: map()

  @doc "The legal links on every checkout (privacy policy, terms)."
  @callback links() :: [map()]

  @doc "The loyalty memberships answering the platform's claims, `nil` when none apply."
  @callback loyalty(context()) :: map() | nil

  @doc "The payment terms for a checkout, `nil` or `[]` when only immediate payment is offered."
  @callback payment_terms(context()) :: [map()] | nil

  @doc "Charges the instruments at completion; `{:error, reason}` becomes a `payment_failed` message."
  @callback authorize(instruments :: [map()]) :: :ok | {:error, term()}

  @doc """
  The HTTP client bazaar reaches platforms with: `%{get: fn url -> ... end,
  post: fn url, body, headers -> ... end}`, each answering `{:ok, %{status:
  integer, body: term}}` or `{:error, reason}`. The default is
  `Bazaar.Http.Req.client/0` when [Req](https://hex.pm/packages/req) is in
  your dependencies, so webhooks and profile lookups work with no code;
  without Req it is `nil`, and bazaar makes no outbound requests at all.
  """
  @callback http_client() :: %{get: function(), post: function()} | nil

  @doc """
  The key order webhooks are signed with, whose public half belongs in
  `business_profile/0`'s `"keys"`. `nil` (the default) delivers unsigned,
  which the spec forbids.
  """
  @callback signing_key() :: Bazaar.Signing.Key.t() | nil

  @doc """
  Where webhook deliveries run: a `Task.Supervisor` name (default
  `Bazaar.TaskSupervisor`, which bazaar starts) or `nil` to deliver inline.
  """
  @callback webhook_task_supervisor() :: atom() | nil

  @doc "The fulfillment capability's `config` in discovery: multi-destination methods and method combinations."
  @callback fulfillment_config() :: map()

  @doc """
  Called once an order is placed. The default delivers the signed order to
  the platform (see `Bazaar.Webhook.deliver_order/3`); override to do it
  yourself or to do more.
  """
  @callback order_placed(order :: map(), conn :: Plug.Conn.t()) :: term()

  @doc """
  Called after an order changed (events, adjustments); the spec has the
  platform sent the full order again, which the default does.
  """
  @callback order_updated(order :: map(), conn :: Plug.Conn.t()) :: term()

  @doc "The catalog, products in the spec's shape."
  @callback products() :: [map()]

  @doc "The stores, locations in the spec's shape."
  @callback locations() :: [map()]

  @doc "Whether a store serves a target, a map with a `point` (geo) or an `address` (locality); `:unsupported` rejects such requests."
  @callback serves?(location :: map(), target :: map()) :: boolean() | :unsupported

  @doc "Whether a store can currently provide every item; `:unsupported` rejects such requests."
  @callback stocks?(location :: map(), item_ids :: [String.t()]) :: boolean() | :unsupported

  defmacro __using__(_opts) do
    quote do
      @behaviour Bazaar.Shop

      @impl Bazaar.Shop
      def fulfillment_options(_destination, _context), do: nil

      @impl Bazaar.Shop
      def pickup_locations(_context), do: nil

      @impl Bazaar.Shop
      def stored_addresses(_buyer), do: nil

      @impl Bazaar.Shop
      def discount(_code, _running_total), do: nil

      @impl Bazaar.Shop
      def payment_handlers, do: %{}

      @impl Bazaar.Shop
      def links do
        [
          %{"type" => "privacy_policy", "url" => base_url() <> "/privacy"},
          %{"type" => "terms_of_service", "url" => base_url() <> "/terms"}
        ]
      end

      @impl Bazaar.Shop
      def loyalty(_context), do: nil

      @impl Bazaar.Shop
      def payment_terms(_context), do: nil

      @impl Bazaar.Shop
      def authorize([]), do: {:error, "A payment instrument is required"}
      def authorize(_instruments), do: :ok

      @impl Bazaar.Shop
      def http_client do
        if Code.ensure_loaded?(Bazaar.Http.Req), do: Bazaar.Http.Req.client()
      end

      @impl Bazaar.Shop
      def signing_key, do: nil

      @impl Bazaar.Shop
      def webhook_task_supervisor, do: Bazaar.TaskSupervisor

      @impl Bazaar.Shop
      def fulfillment_config, do: %{"multi_destination" => [], "method_combinations" => []}

      @impl Bazaar.Shop
      def order_placed(order, conn), do: Bazaar.Webhook.deliver_order(order, __MODULE__, conn)

      @impl Bazaar.Shop
      def order_updated(order, conn), do: Bazaar.Webhook.deliver_order(order, __MODULE__, conn)

      @impl Bazaar.Shop
      def products, do: []

      @impl Bazaar.Shop
      def locations, do: []

      @impl Bazaar.Shop
      def serves?(_location, _target), do: :unsupported

      @impl Bazaar.Shop
      def stocks?(_location, _item_ids), do: :unsupported

      defoverridable fulfillment_options: 2,
                     pickup_locations: 1,
                     stored_addresses: 1,
                     discount: 2,
                     payment_handlers: 0,
                     links: 0,
                     loyalty: 1,
                     payment_terms: 1,
                     authorize: 1,
                     http_client: 0,
                     signing_key: 0,
                     webhook_task_supervisor: 0,
                     fulfillment_config: 0,
                     order_placed: 2,
                     order_updated: 2,
                     products: 0,
                     locations: 0,
                     serves?: 2,
                     stocks?: 2
    end
  end
end
