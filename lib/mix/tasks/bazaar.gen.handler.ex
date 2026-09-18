defmodule Mix.Tasks.Bazaar.Gen.Handler do
  @shortdoc "Generates a UCP handler that answers on first boot"

  @moduledoc """
  Generates a `Bazaar.Handler` for your app, built on the library's checkout,
  cart, catalog and order helpers, with placeholder data so it answers on
  first boot, plus an in-memory store. Then prints the router, endpoint and
  supervision wiring the app still needs.

      $ mix bazaar.gen.handler MyApp.CommerceHandler
      $ mix bazaar.gen.handler MyApp.CommerceHandler --capabilities checkout,orders,fulfillment,discount,cart,catalog --name "My Store"

  ## Options

    * `--capabilities` - Comma-separated capabilities (default:
      `checkout,orders,fulfillment`). `checkout` is always on; `buyer_consent`
      needs no code and rides along with it.
    * `--name` - The store name in the discovery profile (default: derived
      from the module's app)
    * `--output-dir` - Where `lib/` files go (default: `lib`)

  The generated functions under "Your store" are the ones to replace with your
  catalog, rates and storage. See the getting started guide.
  """

  use Mix.Task

  @capabilities ~w(checkout orders fulfillment discount cart catalog)
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

    assigns = [
      module: module,
      store: module <> ".Store",
      app: app,
      name: Keyword.get(opts, :name, app_module),
      capabilities: Enum.map(capabilities, &String.to_atom/1) ++ [:buyer_consent],
      cart?: "cart" in capabilities,
      catalog?: "catalog" in capabilities,
      orders?: "orders" in capabilities,
      fulfillment?: "fulfillment" in capabilities,
      discount?: "discount" in capabilities
    ]

    write("handler.ex.eex", path <> ".ex", assigns)
    write("store.ex.eex", Path.join(path, "store.ex"), assigns)

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

    Now wire it into the app:

    1. Read the raw body for signature checks, in your endpoint's Plug.Parsers:

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
          plug Bazaar.Plugs.VerifySignature, http_client: &#{module}.Http.get/1  # optional, see the plugs guide
        end

        scope "/" do
          pipe_through :ucp
          bazaar_routes "/", #{module}
        end

    3. Start the store and the idempotency table in lib/#{app}/application.ex:

        children = [
          #{module}.Store,
          Bazaar.Idempotency.ETS,
          ...
        ]

    4. Tell the handler where it lives, in config/runtime.exs:

        config #{inspect(app)}, bazaar_base_url: System.get_env("BASE_URL", "http://localhost:4000")

    Then boot and try it:

        curl localhost:4000/.well-known/ucp
        curl -X POST localhost:4000/checkout-sessions -H 'content-type: application/json' \\
          -d '{"currency":"USD","line_items":[{"item":{"id":"sample"},"quantity":2}]}'

    The functions under "Your store" in #{path_hint(module)} are the ones to replace.
    """
  end

  defp path_hint(module), do: "lib/" <> Macro.underscore(module) <> ".ex"
end
