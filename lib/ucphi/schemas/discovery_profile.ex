defmodule Ucphi.Schemas.DiscoveryProfile do
  @moduledoc """
  Schema for the UCP Discovery Profile.

  This is the manifest served at `/.well-known/ucp` that describes
  the merchant's capabilities, endpoints, and configuration.
  """

  @capability_fields [
    %{name: :name, type: :string, description: "Capability name"},
    %{name: :version, type: :string, description: "Capability version"},
    %{name: :endpoint, type: :string, description: "Relative endpoint path"}
  ]

  @transport_fields [
    %{name: :type, type: :string, description: "Transport type (rest, mcp, a2a)"},
    %{name: :endpoint, type: :string, default: "", description: "Base URL for this transport"},
    %{name: :version, type: :string, description: "Transport version"}
  ]

  @payment_handler_fields [
    %{name: :type, type: :string, description: "Payment handler type"},
    %{name: :enabled, type: :boolean, default: true}
  ]

  @fields [
    %{name: :name, type: :string, description: "Business name"},
    %{name: :description, type: :string, description: "Business description"},
    %{name: :logo_url, type: :string, description: "URL to business logo"},
    %{name: :website, type: :string, description: "Business website URL"},
    %{name: :support_email, type: :string, description: "Support email address"},
    %{name: :capabilities, type: Schemecto.many(@capability_fields, with: &Function.identity/1)},
    %{name: :transports, type: Schemecto.many(@transport_fields, with: &Function.identity/1)},
    %{
      name: :payment_handlers,
      type: Schemecto.many(@payment_handler_fields, with: &Function.identity/1)
    },
    %{name: :metadata, type: :map, default: %{}}
  ]

  @doc "Returns the field definitions."
  def fields, do: @fields

  @doc "Creates a new discovery profile."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
  end

  @doc """
  Builds a discovery profile from handler module configuration.

  ## Example

      profile = Ucphi.Schemas.DiscoveryProfile.from_handler(MyApp.Handler, base_url: "https://api.example.com")
  """
  def from_handler(handler_module, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, "")
    capabilities = handler_module.capabilities()

    %{
      "name" => get_in(handler_module.business_profile(), ["name"]) || "Store",
      "description" => get_in(handler_module.business_profile(), ["description"]),
      "capabilities" => build_capabilities(capabilities),
      "transports" => [
        %{"type" => "rest", "endpoint" => base_url, "version" => "1.0"}
      ]
    }
    |> new()
  end

  defp build_capabilities(capabilities) do
    Enum.map(capabilities, fn
      :checkout ->
        %{"name" => "checkout", "version" => "1.0", "endpoint" => "/checkout-sessions"}

      :orders ->
        %{"name" => "orders", "version" => "1.0", "endpoint" => "/orders"}

      :identity ->
        %{"name" => "identity", "version" => "1.0", "endpoint" => "/identity"}
    end)
  end

  @doc "Generates JSON Schema for this type."
  def json_schema do
    Schemecto.new(@fields) |> Schemecto.to_json_schema()
  end

  @doc "Converts to JSON-encodable map for the discovery endpoint."
  def to_json(changeset) do
    changeset
    |> Ecto.Changeset.apply_changes()
    |> Jason.encode!()
  end
end
