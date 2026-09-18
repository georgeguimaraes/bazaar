defmodule Bazaar.Store.Ecto do
  @moduledoc """
  A `Bazaar.Store` on your Ecto repo.

      defmodule MyApp.CommerceStore do
        use Bazaar.Store.Ecto, repo: MyApp.Repo
      end

  Three tables, created by the migration `mix bazaar.gen.store` writes:
  `bazaar_checkouts` and `bazaar_carts` keep the `Bazaar.Checkout` states as
  opaque binaries (`:erlang.term_to_binary/1`; states are maps with atom keys
  around string-keyed documents, which JSON would not bring back), and
  `bazaar_orders` keeps the order documents as JSON in a map column.
  A checkout remembers the cart it was converted from in `cart_id`, which is
  the conversion index.

  Options: `:repo` (required), `:prefix` for the table names (default
  `"bazaar_"`). Needs `ecto_sql` in your app. Writes are upserts on the id
  (`on_conflict` with a `conflict_target`), which Postgres and SQLite
  support; MySQL does not. The `state` columns are bazaar's to read and
  write: they hold Erlang terms, not something to query.
  """

  defmodule Checkout do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :string, autogenerate: false}
    schema "bazaar_checkouts" do
      field(:state, :binary)
      field(:cart_id, :string)
      timestamps(type: :utc_datetime)
    end
  end

  defmodule Cart do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :string, autogenerate: false}
    schema "bazaar_carts" do
      field(:state, :binary)
      timestamps(type: :utc_datetime)
    end
  end

  defmodule Order do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :string, autogenerate: false}
    schema "bazaar_orders" do
      field(:document, :map)
      timestamps(type: :utc_datetime)
    end
  end

  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)
    prefix = Keyword.get(opts, :prefix, "bazaar_")

    quote do
      @behaviour Bazaar.Store

      import Ecto.Query, only: [from: 2]

      @repo unquote(repo)
      @checkouts {unquote(prefix <> "checkouts"), Bazaar.Store.Ecto.Checkout}
      @carts {unquote(prefix <> "carts"), Bazaar.Store.Ecto.Cart}
      @orders {unquote(prefix <> "orders"), Bazaar.Store.Ecto.Order}

      @impl Bazaar.Store
      def get_checkout(id), do: Bazaar.Store.Ecto.get_state(@repo, @checkouts, id)

      @impl Bazaar.Store
      def put_checkout(%{id: id} = state) do
        Bazaar.Store.Ecto.upsert(
          @repo,
          @checkouts,
          %{id: id, state: :erlang.term_to_binary(state)},
          [:state]
        )

        state
      end

      @impl Bazaar.Store
      def get_cart(id), do: Bazaar.Store.Ecto.get_state(@repo, @carts, id)

      @impl Bazaar.Store
      def put_cart(%{id: id} = state) do
        Bazaar.Store.Ecto.upsert(@repo, @carts, %{id: id, state: :erlang.term_to_binary(state)}, [
          :state
        ])

        state
      end

      @impl Bazaar.Store
      def delete_cart(id) do
        {table, schema} = @carts
        @repo.delete_all(from(r in {table, schema}, where: r.id == ^id))
        :ok
      end

      @impl Bazaar.Store
      def get_order(id) do
        {table, schema} = @orders
        @repo.one(from(r in {table, schema}, where: r.id == ^id, select: r.document))
      end

      @impl Bazaar.Store
      def put_order(%{"id" => id} = order) do
        Bazaar.Store.Ecto.upsert(@repo, @orders, %{id: id, document: order}, [:document])
        order
      end

      @impl Bazaar.Store
      def checkout_for_cart(cart_id) do
        {table, schema} = @checkouts

        @repo.one(
          from(r in {table, schema}, where: r.cart_id == ^cart_id, select: r.id, limit: 1)
        )
      end

      @impl Bazaar.Store
      def put_checkout_for_cart(cart_id, checkout_id) do
        {table, schema} = @checkouts

        @repo.update_all(from(r in {table, schema}, where: r.id == ^checkout_id),
          set: [cart_id: cart_id]
        )

        :ok
      end
    end
  end

  @doc false
  def get_state(repo, {table, schema}, id) do
    import Ecto.Query, only: [from: 2]

    case repo.one(from(r in {table, schema}, where: r.id == ^id, select: r.state)) do
      nil -> nil
      binary -> :erlang.binary_to_term(binary)
    end
  end

  @doc false
  def upsert(repo, {table, schema}, attrs, replace) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    row = struct(schema, Map.merge(attrs, %{inserted_at: now, updated_at: now}))

    repo.insert!(Ecto.put_meta(row, source: table),
      on_conflict: {:replace, replace ++ [:updated_at]},
      conflict_target: :id
    )
  end
end
