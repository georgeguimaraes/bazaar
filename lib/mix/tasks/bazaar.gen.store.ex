defmodule Mix.Tasks.Bazaar.Gen.Store do
  @shortdoc "Generates the migration for an Ecto-backed Bazaar.Store"

  @moduledoc """
  Writes the migration `Bazaar.Store.Ecto` needs into your repo's migrations
  directory: `bazaar_checkouts`, `bazaar_carts` and `bazaar_orders`.

      $ mix bazaar.gen.store
      $ mix bazaar.gen.store --repo MyApp.OtherRepo --prefix shop_

  ## Options

    * `--repo` - the repo whose `priv/repo/migrations` receives the file
      (default: the first of your app's `:ecto_repos`)
    * `--prefix` - table name prefix (default: `bazaar_`), matching the
      `prefix:` you give `use Bazaar.Store.Ecto`
    * `--output-dir` - where to write instead of the repo's migrations directory

  Then `mix ecto.migrate`, and a store module:

      defmodule MyApp.CommerceStore do
        use Bazaar.Store.Ecto, repo: MyApp.Repo
      end
  """

  use Mix.Task

  @template :code.priv_dir(:bazaar) |> Path.join("templates/bazaar.gen.store/migration.exs.eex")

  @impl Mix.Task
  def run(args) do
    {opts, _args, _} =
      OptionParser.parse(args, strict: [repo: :string, prefix: :string, output_dir: :string])

    prefix = Keyword.get(opts, :prefix, "bazaar_")
    dir = Keyword.get(opts, :output_dir) || migrations_dir(Keyword.get(opts, :repo))
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")
    path = Path.join(dir, "#{timestamp}_create_bazaar_store.exs")

    module =
      Module.concat([repo_module(Keyword.get(opts, :repo)), "Migrations", "CreateBazaarStore"])

    source = EEx.eval_file(@template, assigns: [module: inspect(module), prefix: prefix])
    Mix.Generator.create_file(path, IO.iodata_to_binary(Code.format_string!(source)) <> "\n")

    Mix.shell().info("""

    Run mix ecto.migrate, then point your handler at a store on the repo:

        defmodule #{app_module()}.CommerceStore do
          use Bazaar.Store.Ecto, repo: #{inspect(repo_module(Keyword.get(opts, :repo)))}#{if prefix != "bazaar_", do: ~s(, prefix: "#{prefix}"), else: ""}
        end

        use Bazaar.Handler, shop: #{app_module()}.Shop, store: #{app_module()}.CommerceStore
    """)
  end

  defp migrations_dir(repo) do
    repo = repo_module(repo)
    app = Mix.Project.config()[:app]
    priv = Path.join(Mix.Project.deps_paths()[app] || File.cwd!(), "priv")
    Path.join([priv, repo |> Module.split() |> List.last() |> Macro.underscore(), "migrations"])
  end

  defp repo_module(nil) do
    app = Mix.Project.config()[:app]

    case Application.get_env(app, :ecto_repos, []) do
      [repo | _] -> repo
      [] -> Mix.raise("no :ecto_repos configured for #{inspect(app)}; pass --repo MyApp.Repo")
    end
  end

  defp repo_module(name), do: Module.concat([name])

  defp app_module do
    Mix.Project.config()[:app] |> Atom.to_string() |> Macro.camelize()
  end
end
