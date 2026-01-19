defmodule Bazaar.Schemas.DiscoveryProfileTest do
  use ExUnit.Case, async: true

  alias Bazaar.Schemas.DiscoveryProfile

  defmodule TestHandler do
    use Bazaar.Handler

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

  defmodule IdentityHandler do
    use Bazaar.Handler

    @impl true
    def capabilities, do: [:checkout, :identity, :discount]

    @impl true
    def business_profile do
      %{"name" => "Identity Store"}
    end
  end

  defmodule PaymentHandler do
    use Bazaar.Handler

    @impl true
    def capabilities, do: [:checkout]

    @impl true
    def business_profile do
      %{
        "name" => "Payment Store",
        "payment_handlers" => [
          %{
            "type" => "stripe",
            "name" => "Stripe",
            "config" => %{"publishable_key" => "pk_test"}
          },
          %{"type" => "paypal", "name" => "PayPal", "config" => %{}}
        ],
        "signing_keys" => [
          %{"kty" => "EC", "kid" => "key-1", "use" => "sig"}
        ]
      }
    end
  end

  describe "from_handler/2" do
    test "builds profile from handler module" do
      profile = DiscoveryProfile.from_handler(TestHandler)

      assert profile["ucp"]["merchant"]["name"] == "Test Handler Store"
      assert profile["ucp"]["merchant"]["description"] == "A store for testing"
    end

    test "includes capabilities from handler" do
      profile = DiscoveryProfile.from_handler(TestHandler)
      capabilities = profile["ucp"]["capabilities"]

      assert length(capabilities) == 2

      capability_names = Enum.map(capabilities, & &1["name"])
      assert "dev.ucp.shopping.checkout" in capability_names
      assert "dev.ucp.shopping.order" in capability_names
    end

    test "sets correct spec and schema URLs for capabilities" do
      profile = DiscoveryProfile.from_handler(TestHandler)
      capabilities = profile["ucp"]["capabilities"]

      checkout_cap = Enum.find(capabilities, &(&1["name"] == "dev.ucp.shopping.checkout"))
      assert checkout_cap["spec"] == "https://ucp.dev/specification/checkout/"
      assert checkout_cap["schema"] == "https://ucp.dev/schemas/shopping/checkout.json"
      assert checkout_cap["version"] == "2026-01-11"
    end

    test "includes base_url in services endpoint" do
      profile = DiscoveryProfile.from_handler(TestHandler, base_url: "https://api.mystore.com")

      services = profile["ucp"]["services"]["dev.ucp.shopping"]
      assert services["rest"]["endpoint"] == "https://api.mystore.com"
    end

    test "uses empty base_url by default" do
      profile = DiscoveryProfile.from_handler(TestHandler)

      services = profile["ucp"]["services"]["dev.ucp.shopping"]
      assert services["rest"]["endpoint"] == ""
    end

    test "extracts primary_domain from base_url" do
      profile = DiscoveryProfile.from_handler(TestHandler, base_url: "https://api.mystore.com")

      assert profile["ucp"]["merchant"]["primary_domain"] == "api.mystore.com"
    end

    test "resolves relative logo_url with base_url" do
      profile = DiscoveryProfile.from_handler(TestHandler, base_url: "https://api.mystore.com")

      assert profile["ucp"]["merchant"]["logo_url"] == "https://api.mystore.com/images/logo.png"
    end

    test "preserves absolute logo_url" do
      defmodule AbsoluteLogoHandler do
        use Bazaar.Handler

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

      assert profile["ucp"]["merchant"]["logo_url"] == "https://cdn.example.com/logo.png"
    end
  end

  describe "from_handler/2 with identity capability" do
    test "includes identity capability" do
      profile = DiscoveryProfile.from_handler(IdentityHandler)
      capabilities = profile["ucp"]["capabilities"]

      capability_names = Enum.map(capabilities, & &1["name"])
      assert "dev.ucp.shopping.identity" in capability_names
    end

    test "includes discount capability" do
      profile = DiscoveryProfile.from_handler(IdentityHandler)
      capabilities = profile["ucp"]["capabilities"]

      capability_names = Enum.map(capabilities, & &1["name"])
      assert "dev.ucp.shopping.discount" in capability_names
    end
  end

  describe "from_handler/2 with payment handlers" do
    test "includes payment handlers" do
      profile = DiscoveryProfile.from_handler(PaymentHandler)
      handlers = profile["payment"]["handlers"]

      assert length(handlers) == 2

      stripe = Enum.find(handlers, &(&1["id"] == "stripe"))
      assert stripe["name"] == "Stripe"
      assert stripe["config"]["publishable_key"] == "pk_test"
    end

    test "includes signing keys" do
      profile = DiscoveryProfile.from_handler(PaymentHandler)

      assert length(profile["signing_keys"]) == 1
      assert hd(profile["signing_keys"])["kid"] == "key-1"
    end
  end

  describe "to_json/1" do
    test "converts profile map to JSON string" do
      profile = DiscoveryProfile.from_handler(TestHandler, base_url: "https://api.example.com")
      json = DiscoveryProfile.to_json(profile)

      assert is_binary(json)

      decoded = JSON.decode!(json)
      assert decoded["ucp"]["merchant"]["name"] == "Test Handler Store"
    end
  end
end
