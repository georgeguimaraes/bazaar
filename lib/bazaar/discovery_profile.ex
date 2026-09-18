defmodule Bazaar.DiscoveryProfile do
  @moduledoc """
  Builder for the UCP Discovery Profile.

  This is the manifest served at `/.well-known/ucp` that describes
  the merchant's capabilities, endpoints, and configuration.

  Follows the UCP business profile document from https://ucp.dev:
  a `ucp` envelope with `services`, `capabilities` and `payment_handlers`
  registries keyed by reverse-domain name, plus an optional `keys` JWK set.
  """

  @ucp_version "2026-08-25"
  @ucp_base "https://ucp.dev/#{@ucp_version}"

  @doc "The UCP spec version this library implements."
  def version, do: @ucp_version

  @doc """
  Builds a UCP-compliant discovery profile from handler module configuration.

  The handler's `business_profile/0` may include:

  - `"name"`, `"description"`, `"logo_url"`, `"support_email"`, `"website"`:
    merchant details, exposed under a top-level `merchant` key
  - `"payment_handlers"`: a list of `%{"name" => "com.stripe", "id" => "stripe", "config" => %{}}`
    entries, where `name` is the handler's reverse-domain namespace
  - `"keys"`: public signing keys as a JWK set

  ## Example

      profile = Bazaar.DiscoveryProfile.from_handler(MyApp.Handler, base_url: "https://api.example.com")
  """
  def from_handler(handler_module, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, "")
    capabilities = handler_module.capabilities()
    business = handler_module.business_profile()

    profile = %{
      "ucp" => %{
        "version" => @ucp_version,
        "services" => %{"dev.ucp.shopping" => [rest_service(base_url)]},
        "capabilities" => build_capabilities(capabilities, handler_module),
        "payment_handlers" => build_payment_handlers(Map.get(business, "payment_handlers", []))
      },
      "merchant" => build_merchant(business, base_url)
    }

    # The schema puts the JWK set at the profile root; the reference platform
    # verifier reads it under `ucp`, so it is published in both places.
    case Map.get(business, "keys") do
      keys when is_list(keys) and keys != [] ->
        profile |> Map.put("keys", keys) |> put_in(["ucp", "keys"], keys)

      _ ->
        profile
    end
  end

  defp rest_service(base_url) do
    %{
      "version" => @ucp_version,
      "spec" => "#{@ucp_base}/specification/overview/",
      "transport" => "rest",
      "schema" => "#{@ucp_base}/services/shopping/rest.openapi.json",
      "endpoint" => base_url
    }
  end

  defp build_merchant(business, base_url) do
    domain = extract_domain(base_url)

    %{
      "name" => Map.get(business, "name", "Store"),
      "description" => Map.get(business, "description"),
      "primary_domain" => domain,
      "logo_url" => resolve_url(Map.get(business, "logo_url"), base_url),
      "support_email" => Map.get(business, "support_email"),
      "website" => Map.get(business, "website") || base_url
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Resolve relative URLs with base_url
  defp resolve_url(nil, _base_url), do: nil
  defp resolve_url("/" <> _ = path, base_url), do: base_url <> path
  defp resolve_url(url, _base_url), do: url

  defp build_capabilities(capabilities, handler_module) do
    capabilities
    |> Enum.flat_map(&capability_entries(&1, handler_module))
    |> Map.new(fn {name, entry} -> {name, [entry]} end)
  end

  defp capability_entries(:checkout, _handler) do
    [{"dev.ucp.shopping.checkout", capability("shopping/checkout", "shopping/checkout")}]
  end

  defp capability_entries(:orders, _handler) do
    [{"dev.ucp.shopping.order", capability("shopping/order", "shopping/order")}]
  end

  defp capability_entries(:fulfillment, handler) do
    entry =
      "shopping/extensions/fulfillment"
      |> capability("shopping/fulfillment")
      |> Map.put("extends", "dev.ucp.shopping.checkout")
      |> Map.put("config", handler.fulfillment_config())

    [{"dev.ucp.shopping.fulfillment", entry}]
  end

  defp capability_entries(:discount, _handler) do
    entry =
      "shopping/extensions/discount"
      |> capability("shopping/discount")
      |> Map.put("extends", "dev.ucp.shopping.checkout")

    [{"dev.ucp.shopping.discount", entry}]
  end

  defp capability_entries(:buyer_consent, _handler) do
    entry =
      "shopping/extensions/buyer-consent"
      |> capability("shopping/buyer_consent")
      |> Map.put("extends", "dev.ucp.shopping.checkout")

    [{"dev.ucp.shopping.buyer_consent", entry}]
  end

  defp capability_entries(:identity, _handler) do
    [
      {"dev.ucp.common.identity_linking",
       capability("common/identity-linking/", "common/identity_linking")}
    ]
  end

  defp capability_entries(:cart, _handler) do
    [{"dev.ucp.shopping.cart", capability("shopping/cart", "shopping/cart")}]
  end

  defp capability_entries(:loyalty, _handler) do
    entry =
      "common/extensions/loyalty"
      |> capability("common/loyalty")
      |> Map.put("extends", [
        "dev.ucp.shopping.catalog.search",
        "dev.ucp.shopping.catalog.lookup",
        "dev.ucp.shopping.cart",
        "dev.ucp.shopping.checkout"
      ])

    [{"dev.ucp.common.loyalty", entry}]
  end

  defp capability_entries(:payment_terms, _handler) do
    entry =
      "payment/extensions/terms"
      |> capability("common/payment_terms")
      |> Map.put("extends", ["dev.ucp.shopping.checkout", "dev.ucp.shopping.order"])

    [{"dev.ucp.common.payment.terms", entry}]
  end

  defp capability_entries(:location, _handler) do
    [
      {"dev.ucp.common.location.search",
       capability("common/location/search", "common/location_search")},
      {"dev.ucp.common.location.lookup",
       capability("common/location/lookup", "common/location_lookup")}
    ]
  end

  defp capability_entries(:catalog, _handler) do
    [
      {"dev.ucp.shopping.catalog.search",
       capability("shopping/catalog/search", "shopping/catalog_search")},
      {"dev.ucp.shopping.catalog.lookup",
       capability("shopping/catalog/lookup", "shopping/catalog_lookup")}
    ]
  end

  defp capability(spec_path, schema_path) do
    %{
      "version" => @ucp_version,
      "spec" => "#{@ucp_base}/specification/#{spec_path}",
      "schema" => "#{@ucp_base}/schemas/#{schema_path}.json"
    }
  end

  defp build_payment_handlers(handlers) when is_list(handlers) do
    Map.new(handlers, fn handler ->
      namespace = Map.get(handler, "name") || Map.get(handler, "type")

      entry =
        %{
          "id" => Map.get(handler, "id") || Map.get(handler, "type"),
          "version" => @ucp_version,
          "spec" => Map.get(handler, "spec"),
          "config" => Map.get(handler, "config", %{})
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
        |> Map.new()

      {namespace, [entry]}
    end)
  end

  defp build_payment_handlers(_), do: %{}

  defp extract_domain(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> nil
    end
  end

  defp extract_domain(_), do: nil

  @doc "Converts profile to JSON string."
  def to_json(profile) when is_map(profile) do
    JSON.encode!(profile)
  end
end
