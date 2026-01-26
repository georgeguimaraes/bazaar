defmodule Bazaar.DiscoveryProfile do
  @moduledoc """
  Builder for the UCP Discovery Profile.

  This is the manifest served at `/.well-known/ucp` that describes
  the merchant's capabilities, endpoints, and configuration.

  Follows the official UCP spec format from https://ucp.dev
  """

  @ucp_version "2026-01-23"
  @ucp_spec_base "https://ucp.dev"

  @doc """
  Builds a UCP-compliant discovery profile from handler module configuration.

  ## Example

      profile = Bazaar.DiscoveryProfile.from_handler(MyApp.Handler, base_url: "https://api.example.com")
  """
  def from_handler(handler_module, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, "")
    capabilities = handler_module.capabilities()
    business = handler_module.business_profile()
    payment_handlers = Map.get(business, "payment_handlers", [])
    signing_keys = Map.get(business, "signing_keys", [])

    base_profile = %{
      "ucp" => %{
        "version" => @ucp_version,
        "merchant" => build_merchant(business, base_url),
        "services" => %{
          "dev.ucp.shopping" => %{
            "version" => @ucp_version,
            "spec" => "#{@ucp_spec_base}/specification/overview/",
            "rest" => %{
              "schema" => "#{@ucp_spec_base}/services/shopping/rest.openapi.json",
              "endpoint" => base_url
            }
          }
        },
        "capabilities" => build_capabilities(capabilities)
      },
      "payment" => build_payment(payment_handlers),
      "signing_keys" => signing_keys
    }

    # Add fulfillment config if capability is declared
    if :fulfillment in capabilities do
      fulfillment_config = handler_module.fulfillment_config()
      put_in(base_profile, ["ucp", "fulfillment"], fulfillment_config)
    else
      base_profile
    end
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

  defp build_capabilities(capabilities) do
    Enum.map(capabilities, fn
      :checkout ->
        %{
          "name" => "dev.ucp.shopping.checkout",
          "version" => @ucp_version,
          "spec" => "#{@ucp_spec_base}/specification/checkout/",
          "schema" => "#{@ucp_spec_base}/schemas/shopping/checkout.json"
        }

      :orders ->
        %{
          "name" => "dev.ucp.shopping.order",
          "version" => @ucp_version,
          "spec" => "#{@ucp_spec_base}/specification/order/",
          "schema" => "#{@ucp_spec_base}/schemas/shopping/order.json"
        }

      :fulfillment ->
        %{
          "name" => "dev.ucp.shopping.fulfillment",
          "version" => @ucp_version,
          "spec" => "#{@ucp_spec_base}/specification/fulfillment/",
          "schema" => "#{@ucp_spec_base}/schemas/shopping/fulfillment.json",
          "extends" => "dev.ucp.shopping.order"
        }

      :identity ->
        %{
          "name" => "dev.ucp.shopping.identity",
          "version" => @ucp_version,
          "spec" => "#{@ucp_spec_base}/specification/identity/",
          "schema" => "#{@ucp_spec_base}/schemas/shopping/identity.json"
        }

      :discount ->
        %{
          "name" => "dev.ucp.shopping.discount",
          "version" => @ucp_version,
          "spec" => "#{@ucp_spec_base}/specification/discount/",
          "schema" => "#{@ucp_spec_base}/schemas/shopping/discount.json"
        }

      :catalog ->
        %{
          "name" => "dev.ucp.shopping.catalog",
          "version" => @ucp_version,
          "spec" => "#{@ucp_spec_base}/specification/catalog/",
          "schema" => "#{@ucp_spec_base}/schemas/shopping/catalog.json"
        }
    end)
  end

  defp build_payment([_ | _] = handlers) do
    %{
      "handlers" =>
        Enum.map(handlers, fn handler ->
          %{
            "id" => Map.get(handler, "type") || Map.get(handler, "id"),
            "name" => Map.get(handler, "name") || String.capitalize(Map.get(handler, "type", "")),
            "version" => @ucp_version,
            "spec" => "#{@ucp_spec_base}/handlers/tokenization/#{Map.get(handler, "type")}/",
            "config" => Map.get(handler, "config", %{})
          }
          |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
          |> Map.new()
        end)
    }
  end

  defp build_payment(_), do: %{"handlers" => []}

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
