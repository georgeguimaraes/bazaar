defmodule Ucphi.Schemas.DiscoveryProfileTest do
  use ExUnit.Case, async: true

  alias Ucphi.Schemas.DiscoveryProfile

  describe "new/1" do
    test "creates valid changeset with basic fields" do
      params = %{
        "name" => "My Store",
        "description" => "The best store ever"
      }

      changeset = DiscoveryProfile.new(params)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == "My Store"
    end

    test "accepts capabilities array" do
      params = %{
        "name" => "Test Store",
        "capabilities" => [
          %{"name" => "checkout", "version" => "1.0", "endpoint" => "/checkout-sessions"},
          %{"name" => "orders", "version" => "1.0", "endpoint" => "/orders"}
        ]
      }

      changeset = DiscoveryProfile.new(params)

      assert changeset.valid?
    end

    test "accepts transports array" do
      params = %{
        "name" => "Test Store",
        "transports" => [
          %{"type" => "rest", "endpoint" => "https://api.example.com", "version" => "1.0"},
          %{"type" => "mcp", "endpoint" => "mcp://example.com", "version" => "1.0"}
        ]
      }

      changeset = DiscoveryProfile.new(params)

      assert changeset.valid?
    end

    test "accepts payment_handlers array" do
      params = %{
        "name" => "Test Store",
        "payment_handlers" => [
          %{"type" => "stripe", "enabled" => true},
          %{"type" => "paypal", "enabled" => false}
        ]
      }

      changeset = DiscoveryProfile.new(params)

      assert changeset.valid?
    end

    test "accepts all optional fields" do
      params = %{
        "name" => "Full Store",
        "description" => "A complete store profile",
        "logo_url" => "https://example.com/logo.png",
        "website" => "https://example.com",
        "support_email" => "support@example.com",
        "capabilities" => [
          %{"name" => "checkout", "version" => "1.0", "endpoint" => "/checkout-sessions"}
        ],
        "transports" => [
          %{"type" => "rest", "endpoint" => "https://api.example.com", "version" => "1.0"}
        ],
        "payment_handlers" => [
          %{"type" => "stripe", "enabled" => true}
        ],
        "metadata" => %{"region" => "us-east-1"}
      }

      changeset = DiscoveryProfile.new(params)

      assert changeset.valid?
    end

    test "sets default empty metadata" do
      params = %{"name" => "Simple Store"}

      changeset = DiscoveryProfile.new(params)
      data = Ecto.Changeset.apply_changes(changeset)

      assert data.metadata == %{}
    end
  end

  describe "from_handler/2" do
    defmodule TestHandler do
      use Ucphi.Handler

      @impl true
      def capabilities, do: [:checkout, :orders]

      @impl true
      def business_profile do
        %{
          "name" => "Test Handler Store",
          "description" => "A store for testing"
        }
      end
    end

    test "builds profile from handler module" do
      changeset = DiscoveryProfile.from_handler(TestHandler)

      assert changeset.valid?

      profile = Ecto.Changeset.apply_changes(changeset)

      assert profile.name == "Test Handler Store"
      assert profile.description == "A store for testing"
    end

    test "includes capabilities from handler" do
      changeset = DiscoveryProfile.from_handler(TestHandler)
      profile = Ecto.Changeset.apply_changes(changeset)

      assert length(profile.capabilities) == 2

      capability_names = Enum.map(profile.capabilities, & &1.name)
      assert "checkout" in capability_names
      assert "orders" in capability_names
    end

    test "sets correct endpoints for capabilities" do
      changeset = DiscoveryProfile.from_handler(TestHandler)
      profile = Ecto.Changeset.apply_changes(changeset)

      checkout_cap = Enum.find(profile.capabilities, &(&1.name == "checkout"))
      orders_cap = Enum.find(profile.capabilities, &(&1.name == "orders"))

      assert checkout_cap.endpoint == "/checkout-sessions"
      assert orders_cap.endpoint == "/orders"
    end

    test "includes base_url in transports" do
      changeset = DiscoveryProfile.from_handler(TestHandler, base_url: "https://api.mystore.com")
      profile = Ecto.Changeset.apply_changes(changeset)

      assert length(profile.transports) == 1

      transport = hd(profile.transports)
      assert transport.type == "rest"
      assert transport.endpoint == "https://api.mystore.com"
      assert transport.version == "1.0"
    end

    test "uses empty base_url by default" do
      changeset = DiscoveryProfile.from_handler(TestHandler)
      profile = Ecto.Changeset.apply_changes(changeset)

      transport = hd(profile.transports)
      # When no base_url is provided, endpoint should be nil or empty
      assert is_nil(transport.endpoint) or transport.endpoint == ""
    end
  end

  describe "from_handler/2 with identity capability" do
    defmodule IdentityHandler do
      use Ucphi.Handler

      @impl true
      def capabilities, do: [:checkout, :identity]

      @impl true
      def business_profile do
        %{"name" => "Identity Store"}
      end
    end

    test "includes identity capability" do
      changeset = DiscoveryProfile.from_handler(IdentityHandler)
      profile = Ecto.Changeset.apply_changes(changeset)

      capability_names = Enum.map(profile.capabilities, & &1.name)
      assert "identity" in capability_names

      identity_cap = Enum.find(profile.capabilities, &(&1.name == "identity"))
      assert identity_cap.endpoint == "/identity"
    end
  end

  describe "json_schema/0" do
    test "generates valid JSON schema" do
      schema = DiscoveryProfile.json_schema()

      assert schema["type"] == "object"
      assert is_map(schema["properties"])
      assert Map.has_key?(schema["properties"], "name")
      assert Map.has_key?(schema["properties"], "capabilities")
      assert Map.has_key?(schema["properties"], "transports")
    end

    test "includes array types for nested fields" do
      schema = DiscoveryProfile.json_schema()

      assert schema["properties"]["capabilities"]["type"] == "array"
      assert schema["properties"]["transports"]["type"] == "array"
      assert schema["properties"]["payment_handlers"]["type"] == "array"
    end
  end

  describe "to_json/1" do
    test "converts changeset to JSON string" do
      params = %{
        "name" => "JSON Store",
        "description" => "Testing JSON output"
      }

      changeset = DiscoveryProfile.new(params)
      json = DiscoveryProfile.to_json(changeset)

      assert is_binary(json)

      decoded = Jason.decode!(json)
      assert decoded["name"] == "JSON Store"
      assert decoded["description"] == "Testing JSON output"
    end
  end

  describe "fields/0" do
    test "returns field definitions" do
      fields = DiscoveryProfile.fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :name end)
      assert Enum.any?(fields, fn f -> f.name == :capabilities end)
      assert Enum.any?(fields, fn f -> f.name == :transports end)
    end
  end
end
