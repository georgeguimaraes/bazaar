defmodule Mix.Tasks.Bazaar.Gen.Handler do
  @shortdoc "Generates a UCP handler that answers on first boot"

  @moduledoc """
  Generates a `Bazaar.Handler` for your app on `Bazaar.Store.ETS` and a
  `Bazaar.Shop` with placeholder data (a sample product, one flat rate) so
  it answers on first boot. Then prints the router, endpoint and
  supervision wiring the app still needs.

      $ mix bazaar.gen.handler MyApp.CommerceHandler
      $ mix bazaar.gen.handler MyApp.CommerceHandler --capabilities checkout,orders,fulfillment,discount,cart,catalog --name "My Store"

  ## Options

    * `--capabilities` - Comma-separated capabilities (default:
      `checkout,orders,fulfillment`; also `discount`, `cart`, `catalog`,
      `location`). `checkout` is always on; `buyer_consent` needs no code
      and rides along with it.
    * `--name` - The store name in the discovery profile (default: derived
      from the module's app)
    * `--output-dir` - Where `lib/` files go (default: `lib`)

  The shop's functions are the ones to replace with your catalog, rates and
  payment provider; the store moves to your database when you outgrow ETS.
  See the getting started guide.
  """

  use Mix.Task

  @capabilities ~w(checkout orders fulfillment discount cart catalog location)
  @default_capabilities ~w(checkout orders fulfillment)
  @templates :code.priv_dir(:bazaar) |> Path.join("templates/bazaar.gen.handler")

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        strict: [capabilities: :string, name: :string, output_dir: :string]
      )

    case args do
      [module] ->
        generate(module, opts)

      _ ->
        Mix.raise(
          "Usage: mix bazaar.gen.handler MyApp.CommerceHandler [--capabilities checkout,orders,...]"
        )
    end
  end

  defp generate(module, opts) do
    capabilities = parse_capabilities(Keyword.get(opts, :capabilities))
    [app_module | _] = String.split(module, ".")
    app = app_module |> Macro.underscore() |> String.to_atom()
    output_dir = Keyword.get(opts, :output_dir, "lib")
    path = Path.join(output_dir, Macro.underscore(module))

    [_ | rest] = parts = String.split(module, ".")
    shop = Enum.join(Enum.drop(parts, -1) ++ ["Shop"], ".")
    _ = rest

    assigns = [
      module: module,
      shop: shop,
      app: app,
      name: Keyword.get(opts, :name, app_module),
      capabilities: Enum.map(capabilities, &String.to_atom/1) ++ [:buyer_consent],
      cart?: "cart" in capabilities,
      catalog?: "catalog" in capabilities,
      location?: "location" in capabilities,
      orders?: "orders" in capabilities,
      fulfillment?: "fulfillment" in capabilities,
      discount?: "discount" in capabilities
    ]

    write("handler.ex.eex", path <> ".ex", assigns)
    write("shop.ex.eex", Path.join(output_dir, Macro.underscore(shop)) <> ".ex", assigns)

    Mix.shell().info(wiring(assigns))
  end

  # Rendered and formatted, so what lands in the app reads like hand-written code.
  defp write(template, path, assigns) do
    source = EEx.eval_file(Path.join(@templates, template), assigns: assigns)
    formatted = IO.iodata_to_binary(Code.format_string!(source)) <> "\n"
    Mix.Generator.create_file(path, formatted)
  end

  defp parse_capabilities(nil), do: @default_capabilities

  defp parse_capabilities(list) do
    names = list |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    case names -- @capabilities do
      [] ->
        Enum.uniq(["checkout" | names])

      unknown ->
        Mix.raise(
          "Unknown capabilities #{inspect(unknown)}; pick from #{Enum.join(@capabilities, ", ")}"
        )
    end
  end

  defp wiring(assigns) do
    module = assigns[:module]
    app = assigns[:app]

    """

    Now wire it into the app, in two places:

    1. Read the raw body in your endpoint's Plug.Parsers, which signature
       checks need (a Content-Digest covers the bytes exactly as sent):

        plug Plug.Parsers,
          parsers: [:json],
          pass: ["*/*"],
          json_decoder: Jason,
          body_reader: {Bazaar.Plugs.RawBody, :read_body, []}

    2. Mount the routes in lib/#{app}_web/router.ex:

        use Bazaar.Phoenix.Router

        pipeline :ucp do
          plug :accepts, ["json"]
          plug Bazaar.Plugs.UCP
        end

        scope "/" do
          pipe_through :ucp
          bazaar_routes "/", #{module}
        end

    Then tell the shop where it lives, in config/runtime.exs:

        config #{inspect(app)}, bazaar_base_url: System.get_env("BASE_URL", "http://localhost:4000")

    Then boot and try it:

        curl localhost:4000/.well-known/ucp
        curl -X POST localhost:4000/checkout-sessions -H 'content-type: application/json' \\
          -d '{"currency":"USD","line_items":[{"item":{"id":"sample"},"quantity":2}]}'

    The functions in lib/#{Macro.underscore(assigns[:shop])}.ex are the ones to replace.
    """
  end
end
