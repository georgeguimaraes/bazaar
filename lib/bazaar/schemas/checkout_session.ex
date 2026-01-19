defmodule Bazaar.Schemas.CheckoutSession do
  @moduledoc """
  Schema for UCP Checkout Sessions.

  A checkout session represents a shopping cart that can be converted
  into an order. It contains line items, buyer information, payment details,
  and required legal links.

  ## Spec Compliance

  This schema follows the official UCP specification:
  - Prices are in **minor units** (cents) as integers
  - Totals are structured with type categorization
  - Status values match the spec enum
  - Links are required for legal compliance

  ## Example

      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "WIDGET-1"}, "quantity" => 2}
        ],
        "payment" => %{}
      }

      case Bazaar.Schemas.CheckoutSession.new(params) do
        %{valid?: true} = changeset ->
          data = Ecto.Changeset.apply_changes(changeset)
          # Process checkout...

        %{valid?: false} = changeset ->
          errors = Bazaar.Errors.from_changeset(changeset)
          # Handle validation errors...
      end
  """

  import Ecto.Changeset

  # Status values per UCP spec
  @status_values [
    :incomplete,
    :requires_escalation,
    :ready_for_complete,
    :complete_in_progress,
    :completed,
    :canceled
  ]
  @status_type Ecto.ParameterizedType.init(Ecto.Enum, values: @status_values)

  # Total type values per UCP spec
  @total_type_values [
    :items_discount,
    :subtotal,
    :discount,
    :fulfillment,
    :tax,
    :fee,
    :total
  ]
  @total_type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @total_type_values)

  # Link type well-known values
  @link_type_values [
    :privacy_policy,
    :terms_of_service,
    :refund_policy,
    :shipping_policy,
    :faq
  ]
  @link_type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @link_type_values)

  # Message severity values
  @severity_values [:recoverable, :requires_buyer_input, :requires_buyer_review]
  @severity_type Ecto.ParameterizedType.init(Ecto.Enum, values: @severity_values)

  # Message content type
  @content_type_values [:plain, :markdown]
  @content_type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @content_type_values)

  # Item fields (minimal for create request, full for response)
  @item_fields [
    %{
      name: :id,
      type: :string,
      description: "Product identifier recognized by platform and business"
    }
  ]

  @item_response_fields [
    %{name: :id, type: :string, description: "Product identifier"},
    %{name: :title, type: :string, description: "Product title"},
    %{name: :price, type: :integer, description: "Unit price in minor currency units (cents)"},
    %{name: :image_url, type: :string, description: "Product image URI"}
  ]

  @line_item_fields [
    %{name: :item, type: Schemecto.one(@item_fields, with: &__MODULE__.validate_item/1)},
    %{name: :quantity, type: :integer, default: 1, description: "Quantity ordered (minimum 1)"}
  ]

  @line_item_response_fields [
    %{name: :item, type: Schemecto.one(@item_response_fields, with: &Function.identity/1)},
    %{name: :quantity, type: :integer, description: "Quantity ordered"}
  ]

  # Buyer fields per UCP spec
  @buyer_fields [
    %{name: :first_name, type: :string, description: "First name of the buyer"},
    %{name: :last_name, type: :string, description: "Last name of the buyer"},
    %{
      name: :full_name,
      type: :string,
      description: "Full name (first_name/last_name take precedence)"
    },
    %{name: :email, type: :string, description: "Email of the buyer"},
    %{name: :phone_number, type: :string, description: "Phone number in E.164 format"}
  ]

  # Postal address fields per UCP spec
  @address_fields [
    %{name: :street_address, type: :string, description: "Street address"},
    %{name: :extended_address, type: :string, description: "Apartment, suite, unit, etc."},
    %{name: :address_locality, type: :string, description: "City"},
    %{name: :address_region, type: :string, description: "State/province (required for US/CA)"},
    %{name: :address_country, type: :string, description: "ISO 3166-1 alpha-2 country code"},
    %{name: :postal_code, type: :string, description: "Postal or ZIP code"},
    %{name: :first_name, type: :string, description: "Recipient first name"},
    %{name: :last_name, type: :string, description: "Recipient last name"},
    %{name: :full_name, type: :string, description: "Recipient full name"},
    %{name: :phone_number, type: :string, description: "Contact phone number"}
  ]

  # Total fields per UCP spec
  @total_fields [
    %{name: :type, type: @total_type_type, description: "Type of total categorization"},
    %{name: :display_text, type: :string, description: "Display text for the amount"},
    %{name: :amount, type: :integer, description: "Amount in minor currency units (cents)"}
  ]

  # Link fields per UCP spec (required for legal compliance)
  @link_fields [
    %{name: :type, type: @link_type_type, description: "Type of link"},
    %{name: :url, type: :string, description: "URL pointing to the content"},
    %{name: :title, type: :string, description: "Optional display text for the link"}
  ]

  # Message fields per UCP spec
  @message_fields [
    %{name: :type, type: :string, description: "Message type: error, warning, or info"},
    %{name: :code, type: :string, description: "Error/message code identifier"},
    %{name: :path, type: :string, description: "JSONPath reference to related component"},
    %{name: :content_type, type: @content_type_type, default: :plain},
    %{name: :content, type: :string, description: "User-facing message description"},
    %{name: :severity, type: @severity_type, description: "Determines resolution responsibility"}
  ]

  # Payment fields (simplified)
  @payment_fields [
    %{
      name: :selected_instrument_id,
      type: :string,
      description: "Selected payment instrument ID"
    },
    %{name: :instruments, type: {:array, :map}, description: "Available payment instruments"}
  ]

  # UCP response wrapper
  @ucp_fields [
    %{name: :name, type: :string, description: "Capability name in reverse-domain notation"},
    %{name: :version, type: :string, description: "Protocol version (YYYY-MM-DD format)"}
  ]

  @fields [
    %{
      name: :ucp,
      type: Schemecto.one(@ucp_fields, with: &Function.identity/1),
      description: "UCP response metadata"
    },
    %{name: :id, type: :string, description: "Unique checkout session identifier"},
    %{
      name: :status,
      type: @status_type,
      default: :incomplete,
      description: "Checkout session status"
    },
    %{name: :currency, type: :string, description: "ISO 4217 currency code"},
    %{
      name: :line_items,
      type: Schemecto.many(@line_item_fields, with: &__MODULE__.validate_line_item/1),
      description: "List of line items being checked out"
    },
    %{name: :buyer, type: Schemecto.one(@buyer_fields, with: &Function.identity/1)},
    %{name: :shipping_address, type: Schemecto.one(@address_fields, with: &Function.identity/1)},
    %{name: :billing_address, type: Schemecto.one(@address_fields, with: &Function.identity/1)},
    %{
      name: :totals,
      type: Schemecto.many(@total_fields, with: &__MODULE__.validate_total/1),
      description: "Different totals for the checkout"
    },
    %{
      name: :links,
      type: Schemecto.many(@link_fields, with: &__MODULE__.validate_link/1),
      description: "Required legal compliance links"
    },
    %{
      name: :messages,
      type: Schemecto.many(@message_fields, with: &Function.identity/1),
      description: "Error/warning/info messages about session state"
    },
    %{name: :payment, type: Schemecto.one(@payment_fields, with: &Function.identity/1)},
    %{
      name: :continue_url,
      type: :string,
      description: "URL for checkout handoff when requires_escalation"
    },
    %{name: :expires_at, type: :string, description: "RFC 3339 expiry timestamp"},
    %{name: :metadata, type: :map, default: %{}, description: "Custom key-value data"},
    %{name: :created_at, type: :utc_datetime},
    %{name: :updated_at, type: :utc_datetime}
  ]

  @doc "Returns the field definitions for this schema."
  def fields, do: @fields

  @doc "Returns the status values."
  def status_values, do: @status_values

  @doc "Returns the total type values."
  def total_type_values, do: @total_type_values

  @doc "Returns the link type values."
  def link_type_values, do: @link_type_values

  @doc "Returns the line item field definitions."
  def line_item_fields, do: @line_item_fields

  @doc "Returns the line item response field definitions."
  def line_item_response_fields, do: @line_item_response_fields

  @doc "Returns the buyer field definitions."
  def buyer_fields, do: @buyer_fields

  @doc "Returns the address field definitions."
  def address_fields, do: @address_fields

  @doc "Returns the total field definitions."
  def total_fields, do: @total_fields

  @doc "Returns the link field definitions."
  def link_fields, do: @link_fields

  @doc "Returns the message field definitions."
  def message_fields, do: @message_fields

  @doc """
  Creates a new checkout session changeset from params (create request).

  ## Required Fields

  - `currency` - ISO 4217 currency code
  - `line_items` - At least one line item with item.id and quantity
  - `payment` - Payment configuration

  ## Example

      changeset = Bazaar.Schemas.CheckoutSession.new(%{
        "currency" => "USD",
        "line_items" => [%{"item" => %{"id" => "SKU-123"}, "quantity" => 1}],
        "payment" => %{}
      })
  """
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
    |> validate_required([:currency, :line_items, :payment])
    |> validate_inclusion(:currency, Bazaar.Currencies.codes())
    |> validate_length(:line_items, min: 1)
  end

  @doc """
  Creates a changeset for a checkout response (with all response fields).
  """
  def response(params \\ %{}) do
    response_fields = [
      %{name: :ucp, type: Schemecto.one(@ucp_fields, with: &Function.identity/1)},
      %{name: :id, type: :string},
      %{name: :status, type: @status_type},
      %{name: :currency, type: :string},
      %{
        name: :line_items,
        type: Schemecto.many(@line_item_response_fields, with: &Function.identity/1)
      },
      %{name: :buyer, type: Schemecto.one(@buyer_fields, with: &Function.identity/1)},
      %{
        name: :totals,
        type: Schemecto.many(@total_fields, with: &__MODULE__.validate_total/1)
      },
      %{
        name: :links,
        type: Schemecto.many(@link_fields, with: &__MODULE__.validate_link/1)
      },
      %{
        name: :messages,
        type: Schemecto.many(@message_fields, with: &Function.identity/1)
      },
      %{name: :payment, type: Schemecto.one(@payment_fields, with: &Function.identity/1)},
      %{name: :continue_url, type: :string},
      %{name: :expires_at, type: :string}
    ]

    Schemecto.new(response_fields, params)
    |> validate_required([:id, :status, :currency, :line_items, :totals, :links, :payment])
    |> validate_continue_url_on_escalation()
  end

  @doc """
  Creates a changeset for updating an existing checkout session.
  """
  def update(existing, params) do
    existing_stringified =
      existing
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    Schemecto.new(@fields, Map.merge(existing_stringified, params))
    |> validate_inclusion(:currency, Bazaar.Currencies.codes())
  end

  @doc "Validates an item changeset."
  def validate_item(changeset) do
    changeset
    |> validate_required([:id])
  end

  @doc "Validates a line item changeset."
  def validate_line_item(changeset) do
    changeset
    |> validate_required([:item, :quantity])
    |> validate_number(:quantity, greater_than_or_equal_to: 1)
  end

  @doc "Validates a total changeset."
  def validate_total(changeset) do
    changeset
    |> validate_required([:type, :amount])
    |> validate_number(:amount, greater_than_or_equal_to: 0)
  end

  @doc "Validates a link changeset."
  def validate_link(changeset) do
    changeset
    |> validate_required([:type, :url])
    |> validate_format(:url, ~r/^https?:\/\//, message: "must be a valid URL")
  end

  # Private: validates continue_url is present when status is requires_escalation
  defp validate_continue_url_on_escalation(changeset) do
    status = get_field(changeset, :status)

    if status == :requires_escalation do
      validate_required(changeset, [:continue_url])
    else
      changeset
    end
  end

  @doc "Generates JSON Schema for the create request."
  def json_schema do
    json_schema_fields =
      @fields
      |> Enum.reject(fn field -> field[:type] == :utc_datetime end)

    Schemecto.new(json_schema_fields) |> Schemecto.to_json_schema()
  end

  @doc """
  Converts an amount in major units (dollars) to minor units (cents).

  ## Example

      iex> Bazaar.Schemas.CheckoutSession.to_minor_units(19.99)
      1999
  """
  def to_minor_units(amount) when is_float(amount), do: round(amount * 100)
  def to_minor_units(amount) when is_integer(amount), do: amount * 100

  def to_minor_units(%Decimal{} = amount) do
    amount |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_integer()
  end

  @doc """
  Converts an amount in minor units (cents) to major units (dollars).

  ## Example

      iex> Bazaar.Schemas.CheckoutSession.to_major_units(1999)
      19.99
  """
  def to_major_units(amount) when is_integer(amount), do: amount / 100
end
