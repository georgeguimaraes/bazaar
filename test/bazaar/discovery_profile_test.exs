defmodule Bazaar.DiscoveryProfileTest do
  use ExUnit.Case, async: true

  alias Bazaar.DiscoveryProfile
  alias Bazaar.Validator

  @version DiscoveryProfile.version()

  defmodule TestHandler do
    use Bazaar.Handler, shop: Bazaar.TestShop, store: Bazaar.Store.ETS

    @impl true
    def capabilities, do: [:checkout, :orders]

    @impl true
    def business_profile do
      %{
        "name" => "Test Handler Store",
        "description" => "A store for testing",
        "logo_url" => "/images/logo.png",
        "support_email" => "support@test.com"
      }
    end
  end

  defmodule EverythingShop do
    use Bazaar.Shop

    defdelegate base_url, to: Bazaar.TestShop
    defdelegate item(id), to: Bazaar.TestShop

    @impl true
    def fulfillment_config do
      %{
        "multi_destination" => [%{"method" => "shipping"}],
        "method_combinations" => [["shipping", "pickup"]]
      }
    end
  end

  defmodule EverythingHandler do
    use Bazaar.Handler, shop: EverythingShop, store: Bazaar.Store.ETS

    @impl true
    def capabilities,
      do: [
        :checkout,
        :orders,
        :fulfillment,
        :identity,
        :discount,
        :buyer_consent,
        :catalog,
        :cart,
        :location,
        :loyalty,
        :payment_terms
      ]

    @impl true
    def business_profile do
      %{
        "name" => "Everything Store",
        "payment_handlers" => [
          %{
            "name" => "com.stripe",
            "id" => "stripe",
            "spec" => "https://stripe.com/docs/ucp",
            "config" => %{"publishable_key" => "pk_test"}
          },
          %{"name" => "com.paypal", "id" => "paypal", "config" => %{}}
        ],
        "keys" => [
          %{
            "kty" => "EC",
            "kid" => "key-1",
            "use" => "sig",
            "crv" => "P-256",
            "x" => "f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU",
            "y" => "x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0"
          }
        ]
      }
    end
  end

  describe "from_handler/2" do
    test "builds merchant details from handler module" do
      profile = DiscoveryProfile.from_handler(TestHandler)

      assert profile["merchant"]["name"] == "Test Handler Store"
      assert profile["merchant"]["description"] == "A store for testing"
    end

    test "registers capabilities by reverse-domain name" do
      profile = DiscoveryProfile.from_handler(TestHandler)
      capabilities = profile["ucp"]["capabilities"]

      assert Map.keys(capabilities) |> Enum.sort() ==
               ["dev.ucp.shopping.checkout", "dev.ucp.shopping.order"]
    end

    test "sets versioned spec and schema URLs for capabilities" do
      profile = DiscoveryProfile.from_handler(TestHandler)
      [checkout_cap] = profile["ucp"]["capabilities"]["dev.ucp.shopping.checkout"]

      assert checkout_cap["version"] == @version
      assert checkout_cap["spec"] == "https://ucp.dev/#{@version}/specification/shopping/checkout"

      assert checkout_cap["schema"] ==
               "https://ucp.dev/#{@version}/schemas/shopping/checkout.json"
    end

    test "binds the shopping service to the REST transport at base_url" do
      profile = DiscoveryProfile.from_handler(TestHandler, base_url: "https://api.mystore.com")
      [service] = profile["ucp"]["services"]["dev.ucp.shopping"]

      assert service["transport"] == "rest"
      assert service["endpoint"] == "https://api.mystore.com"
      assert service["version"] == @version
    end

    test "uses empty base_url by default" do
      profile = DiscoveryProfile.from_handler(TestHandler)
      [service] = profile["ucp"]["services"]["dev.ucp.shopping"]

      assert service["endpoint"] == ""
    end

    test "extracts primary_domain from base_url" do
      profile = DiscoveryProfile.from_handler(TestHandler, base_url: "https://api.mystore.com")

      assert profile["merchant"]["primary_domain"] == "api.mystore.com"
    end

    test "resolves relative logo_url with base_url" do
      profile = DiscoveryProfile.from_handler(TestHandler, base_url: "https://api.mystore.com")

      assert profile["merchant"]["logo_url"] == "https://api.mystore.com/images/logo.png"
    end

    test "preserves absolute logo_url" do
      defmodule AbsoluteLogoHandler do
        use Bazaar.Handler, shop: Bazaar.TestShop, store: Bazaar.Store.ETS

        @impl true
        def capabilities, do: [:checkout]

        @impl true
        def business_profile do
          %{
            "name" => "Absolute Logo Store",
            "logo_url" => "https://cdn.example.com/logo.png"
          }
        end
      end

      profile =
        DiscoveryProfile.from_handler(AbsoluteLogoHandler, base_url: "https://api.mystore.com")

      assert profile["merchant"]["logo_url"] == "https://cdn.example.com/logo.png"
    end

    test "omits keys and payment handlers when the handler declares none" do
      profile = DiscoveryProfile.from_handler(TestHandler)

      refute Map.has_key?(profile, "keys")
      assert profile["ucp"]["payment_handlers"] == %{}
    end
  end

  describe "from_handler/2 with every capability" do
    test "maps identity, discount and catalog to their UCP capability names" do
      profile = DiscoveryProfile.from_handler(EverythingHandler)
      capabilities = profile["ucp"]["capabilities"]

      assert [identity] = capabilities["dev.ucp.common.identity_linking"]
      assert identity["schema"] =~ "/schemas/common/identity_linking.json"

      assert [discount] = capabilities["dev.ucp.shopping.discount"]
      assert discount["extends"] == "dev.ucp.shopping.checkout"

      assert [consent] = capabilities["dev.ucp.shopping.buyer_consent"]
      assert consent["schema"] =~ "/schemas/shopping/buyer_consent.json"
      assert consent["extends"] == "dev.ucp.shopping.checkout"

      assert Map.has_key?(capabilities, "dev.ucp.shopping.cart")
      assert Map.has_key?(capabilities, "dev.ucp.common.location.search")

      assert [%{"extends" => [_, _, _, "dev.ucp.shopping.checkout"]}] =
               capabilities["dev.ucp.common.loyalty"]

      assert [%{"extends" => ["dev.ucp.shopping.checkout", "dev.ucp.shopping.order"]}] =
               capabilities["dev.ucp.common.payment.terms"]

      assert Map.has_key?(capabilities, "dev.ucp.common.location.lookup")
      assert Map.has_key?(capabilities, "dev.ucp.shopping.catalog.search")
      assert Map.has_key?(capabilities, "dev.ucp.shopping.catalog.lookup")
    end

    test "extensions extend only the capabilities the handler advertises, and the profile validates" do
      defmodule CheckoutOnlyExtensions do
        use Bazaar.Handler, shop: Bazaar.TestShop, store: Bazaar.Store.ETS

        @impl true
        def capabilities, do: [:checkout, :loyalty, :payment_terms]
      end

      profile = DiscoveryProfile.from_handler(CheckoutOnlyExtensions)
      assert {:ok, _} = Bazaar.Validator.validate(profile, :profile)
      capabilities = profile["ucp"]["capabilities"]

      assert [%{"extends" => ["dev.ucp.shopping.checkout"]}] =
               capabilities["dev.ucp.common.loyalty"]

      assert [%{"extends" => ["dev.ucp.shopping.checkout"]}] =
               capabilities["dev.ucp.common.payment.terms"]

      assert {:ok, _} =
               Bazaar.Validator.validate(
                 DiscoveryProfile.from_handler(EverythingHandler),
                 :profile
               )
    end

    test "advertises a transport the business serves itself alongside bazaar's REST binding" do
      defmodule McpShop do
        use Bazaar.Shop

        defdelegate base_url, to: Bazaar.TestShop
        defdelegate item(id), to: Bazaar.TestShop
      end

      defmodule McpHandler do
        use Bazaar.Handler, shop: McpShop, store: Bazaar.Store.ETS

        @impl true
        def business_profile do
          %{
            "name" => "Tools and REST",
            "services" => %{
              "dev.ucp.shopping" => [
                DiscoveryProfile.service(transport: "mcp", endpoint: "https://shop.test/ucp/mcp")
              ]
            }
          }
        end
      end

      profile = DiscoveryProfile.from_handler(McpHandler, base_url: "https://shop.test")
      assert {:ok, _} = Bazaar.Validator.validate(profile, :profile)

      assert [
               %{"transport" => "rest", "endpoint" => "https://shop.test"},
               %{
                 "transport" => "mcp",
                 "endpoint" => "https://shop.test/ucp/mcp",
                 "version" => "2026-08-25"
               }
             ] = profile["ucp"]["services"]["dev.ucp.shopping"]

      # A business that advertises nothing extra still gets exactly the one entry.
      assert [%{"transport" => "rest"}] =
               DiscoveryProfile.from_handler(EverythingHandler)["ucp"]["services"][
                 "dev.ucp.shopping"
               ]
    end

    test "carries the fulfillment config on the fulfillment capability" do
      profile = DiscoveryProfile.from_handler(EverythingHandler)
      [fulfillment] = profile["ucp"]["capabilities"]["dev.ucp.shopping.fulfillment"]

      assert fulfillment["extends"] == "dev.ucp.shopping.checkout"
      assert fulfillment["config"]["multi_destination"] == [%{"method" => "shipping"}]
      assert fulfillment["config"]["method_combinations"] == [["shipping", "pickup"]]
    end

    test "registers payment handlers by namespace" do
      profile = DiscoveryProfile.from_handler(EverythingHandler)
      handlers = profile["ucp"]["payment_handlers"]

      assert Map.keys(handlers) |> Enum.sort() == ["com.paypal", "com.stripe"]

      [stripe] = handlers["com.stripe"]
      assert stripe["id"] == "stripe"
      assert stripe["version"] == @version
      assert stripe["spec"] == "https://stripe.com/docs/ucp"
      assert stripe["config"]["publishable_key"] == "pk_test"

      [paypal] = handlers["com.paypal"]
      refute Map.has_key?(paypal, "spec")
    end

    test "publishes signing keys as a JWK set" do
      profile = DiscoveryProfile.from_handler(EverythingHandler)

      assert [%{"kid" => "key-1", "kty" => "EC"}] = profile["keys"]
      assert profile["ucp"]["keys"] == profile["keys"]
    end

    test "validates against the UCP business profile schema" do
      for handler <- [TestHandler, EverythingHandler] do
        profile = DiscoveryProfile.from_handler(handler, base_url: "https://api.mystore.com")

        case Validator.validate_profile(profile) do
          {:ok, _} -> :ok
          {:error, errors} -> flunk("#{inspect(handler)} profile is invalid: #{inspect(errors)}")
        end
      end
    end
  end

  describe "to_json/1" do
    test "converts profile map to JSON string" do
      profile = DiscoveryProfile.from_handler(TestHandler, base_url: "https://api.example.com")
      json = DiscoveryProfile.to_json(profile)

      assert is_binary(json)

      decoded = JSON.decode!(json)
      assert decoded["merchant"]["name"] == "Test Handler Store"
    end
  end
end
