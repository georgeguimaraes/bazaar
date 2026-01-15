defmodule Ucphi.Schemas.CheckoutSession do
  @moduledoc """
  Schema for UCP Checkout Sessions.

  A checkout session represents a shopping cart that can be converted
  into an order. It contains line items, buyer information, and
  payment details.

  ## Example

      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"sku" => "WIDGET-1", "name" => "Widget", "quantity" => 2, "unit_price" => "19.99"}
        ]
      }

      case Ucphi.Schemas.CheckoutSession.new(params) do
        %{valid?: true} = changeset ->
          data = Ecto.Changeset.apply_changes(changeset)
          # Process checkout...

        %{valid?: false} = changeset ->
          errors = Ucphi.Errors.from_changeset(changeset)
          # Handle validation errors...
      end
  """

  import Ecto.Changeset

  @status_values [:open, :complete, :expired, :cancelled]
  @status_type Ecto.ParameterizedType.init(Ecto.Enum, values: @status_values)

  @line_item_fields [
    %{name: :sku, type: :string, description: "Stock keeping unit identifier"},
    %{name: :name, type: :string, description: "Display name of the item"},
    %{name: :description, type: :string, description: "Item description"},
    %{name: :quantity, type: :integer, default: 1, description: "Quantity ordered"},
    %{name: :unit_price, type: :decimal, description: "Price per unit"},
    %{name: :image_url, type: :string, description: "URL to item image"}
  ]

  @buyer_fields [
    %{name: :email, type: :string, description: "Buyer email address"},
    %{name: :name, type: :string, description: "Buyer full name"},
    %{name: :phone, type: :string, description: "Buyer phone number"}
  ]

  @address_fields [
    %{name: :line1, type: :string, description: "Street address line 1"},
    %{name: :line2, type: :string, description: "Street address line 2"},
    %{name: :city, type: :string, description: "City"},
    %{name: :state, type: :string, description: "State or province"},
    %{name: :postal_code, type: :string, description: "Postal or ZIP code"},
    %{name: :country, type: :string, description: "ISO 3166-1 alpha-2 country code"}
  ]

  @fields [
    %{name: :id, type: :string, description: "Unique session identifier"},
    %{name: :status, type: @status_type, default: :open},
    %{name: :currency, type: :string, description: "ISO 4217 currency code"},
    %{name: :subtotal, type: :decimal, description: "Sum of line item totals"},
    %{name: :tax, type: :decimal, description: "Tax amount"},
    %{name: :shipping, type: :decimal, description: "Shipping cost"},
    %{name: :total, type: :decimal, description: "Total amount"},
    %{
      name: :line_items,
      type: Schemecto.many(@line_item_fields, with: &__MODULE__.validate_line_item/1)
    },
    %{name: :buyer, type: Schemecto.one(@buyer_fields, with: &Function.identity/1)},
    %{name: :shipping_address, type: Schemecto.one(@address_fields, with: &Function.identity/1)},
    %{name: :billing_address, type: Schemecto.one(@address_fields, with: &Function.identity/1)},
    %{name: :metadata, type: :map, default: %{}, description: "Custom key-value data"},
    %{name: :created_at, type: :utc_datetime},
    %{name: :updated_at, type: :utc_datetime},
    %{name: :expires_at, type: :utc_datetime}
  ]

  @doc "Returns the field definitions for this schema."
  def fields, do: @fields

  @doc "Returns the line item field definitions."
  def line_item_fields, do: @line_item_fields

  @doc "Returns the buyer field definitions."
  def buyer_fields, do: @buyer_fields

  @doc "Returns the address field definitions."
  def address_fields, do: @address_fields

  @doc """
  Creates a new checkout session changeset from params.

  ## Example

      changeset = Ucphi.Schemas.CheckoutSession.new(%{
        "currency" => "USD",
        "line_items" => [%{"sku" => "ABC", "quantity" => 1, "unit_price" => "9.99"}]
      })
  """
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
    |> validate_required([:currency, :line_items])
    |> validate_inclusion(:currency, Ucphi.Currencies.codes())
    |> validate_length(:line_items, min: 1)
  end

  @doc """
  Creates a changeset for updating an existing checkout session.
  """
  def update(existing, params) do
    existing_stringified =
      existing
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    Schemecto.new(@fields, Map.merge(existing_stringified, params))
    |> validate_inclusion(:currency, Ucphi.Currencies.codes())
  end

  @doc "Validates a line item changeset."
  def validate_line_item(changeset) do
    changeset
    |> validate_required([:sku, :quantity, :unit_price])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
  end

  @doc "Generates JSON Schema for this type."
  def json_schema do
    # Filter out :utc_datetime fields as Schemecto doesn't support them in JSON Schema
    json_schema_fields =
      @fields
      |> Enum.reject(fn field -> field[:type] == :utc_datetime end)

    Schemecto.new(json_schema_fields) |> Schemecto.to_json_schema()
  end
end
