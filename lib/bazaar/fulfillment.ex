defmodule Bazaar.Fulfillment do
  @moduledoc """
  Schemas for UCP fulfillment capability.

  Fulfillment enables businesses to advertise support for physical goods
  delivery through shipping, pickup, and similar methods.

  ## During Checkout

  The agent sends fulfillment methods with destinations, and the merchant
  responds with available options and pricing:

      # Agent request
      %{
        "fulfillment" => %{
          "methods" => [
            %{
              "type" => "shipping",
              "line_item_ids" => ["item_1", "item_2"],
              "destinations" => [
                %{
                  "type" => "address",
                  "street" => "123 Main St",
                  "locality" => "San Francisco",
                  "region" => "CA",
                  "postal_code" => "94102",
                  "country" => "US"
                }
              ]
            }
          ]
        }
      }

      # Merchant response includes options with pricing
      %{
        "fulfillment" => %{
          "methods" => [
            %{
              "id" => "method_1",
              "type" => "shipping",
              "groups" => [
                %{
                  "id" => "group_1",
                  "options" => [
                    %{"id" => "opt_1", "title" => "Standard", "totals" => [...]},
                    %{"id" => "opt_2", "title" => "Express", "totals" => [...]}
                  ]
                }
              ]
            }
          ]
        }
      }

  ## After Order

  Fulfillment events track shipment status (shipped, delivered, etc.)
  See `Bazaar.Schemas.Shopping.Order` for order fulfillment fields.
  """

  # Fulfillment method types
  @method_type_values [:shipping, :pickup]
  @method_type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @method_type_values)

  # Destination types
  @destination_type_values [:address, :pickup_location]
  @destination_type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @destination_type_values)

  # ============================================================================
  # Request Schemas (from agent)
  # ============================================================================

  @address_fields [
    %{name: :street, type: :string, description: "Street address"},
    %{name: :locality, type: :string, description: "City or locality"},
    %{name: :region, type: :string, description: "State, province, or region"},
    %{name: :postal_code, type: :string, description: "Postal or ZIP code"},
    %{
      name: :country,
      type: :string,
      required: true,
      description: "ISO 3166-1 alpha-2 country code"
    }
  ]

  @pickup_location_fields [
    %{name: :id, type: :string, description: "Pickup location identifier"},
    %{name: :name, type: :string, description: "Location name"},
    %{name: :address, type: :map, description: "Location address"}
  ]

  @destination_request_fields [
    %{name: :type, type: @destination_type_type, required: true, description: "Destination type"},
    %{name: :street, type: :string, description: "Street address (for address type)"},
    %{name: :locality, type: :string, description: "City (for address type)"},
    %{name: :region, type: :string, description: "Region (for address type)"},
    %{name: :postal_code, type: :string, description: "Postal code (for address type)"},
    %{name: :country, type: :string, description: "Country code (for address type)"},
    %{name: :location_id, type: :string, description: "Pickup location ID (for pickup type)"}
  ]

  @group_request_fields [
    %{name: :id, type: :string, description: "Group identifier"},
    %{name: :selected_option_id, type: :string, description: "Selected fulfillment option ID"}
  ]

  @method_request_fields [
    %{name: :id, type: :string, description: "Method identifier for updates"},
    %{
      name: :type,
      type: @method_type_type,
      required: true,
      description: "Fulfillment method type"
    },
    %{
      name: :line_item_ids,
      type: {:array, :string},
      description: "Line items for this fulfillment method"
    },
    %{
      name: :destinations,
      type: {:array, :map},
      description: "Delivery destinations"
    },
    %{name: :selected_destination_id, type: :string, description: "Selected destination ID"},
    %{
      name: :groups,
      type: {:array, :map},
      description: "Fulfillment groups with selected options"
    }
  ]

  @available_method_request_fields [
    %{name: :type, type: @method_type_type, required: true, description: "Method type"},
    %{
      name: :line_item_ids,
      type: {:array, :string},
      description: "Line items to check availability"
    }
  ]

  @fulfillment_request_fields [
    %{
      name: :methods,
      type: {:array, :map},
      description: "Fulfillment methods with destinations"
    },
    %{
      name: :available_methods,
      type: {:array, :map},
      description: "Request availability for method types"
    }
  ]

  # ============================================================================
  # Response Schemas (from merchant)
  # ============================================================================

  @total_fields [
    %{name: :type, type: :string, required: true, description: "Total type (fulfillment)"},
    %{
      name: :amount,
      type: :integer,
      required: true,
      description: "Amount in minor currency units"
    }
  ]

  @option_response_fields [
    %{name: :id, type: :string, required: true, description: "Option identifier"},
    %{name: :title, type: :string, required: true, description: "Display title"},
    %{name: :description, type: :string, description: "Additional description"},
    %{name: :carrier, type: :string, description: "Carrier name"},
    %{
      name: :earliest_fulfillment_time,
      type: :string,
      description: "Earliest delivery (ISO 8601)"
    },
    %{name: :latest_fulfillment_time, type: :string, description: "Latest delivery (ISO 8601)"},
    %{name: :totals, type: {:array, :map}, description: "Price breakdown"}
  ]

  @group_response_fields [
    %{name: :id, type: :string, required: true, description: "Group identifier"},
    %{name: :line_item_ids, type: {:array, :string}, description: "Line items in this group"},
    %{name: :options, type: {:array, :map}, description: "Available fulfillment options"},
    %{name: :selected_option_id, type: :string, description: "Selected option ID"}
  ]

  @destination_response_fields [
    %{name: :id, type: :string, required: true, description: "Destination identifier"},
    %{name: :type, type: @destination_type_type, required: true, description: "Destination type"},
    %{name: :street, type: :string, description: "Street address"},
    %{name: :locality, type: :string, description: "City"},
    %{name: :region, type: :string, description: "Region"},
    %{name: :postal_code, type: :string, description: "Postal code"},
    %{name: :country, type: :string, description: "Country code"},
    %{name: :name, type: :string, description: "Location name (for pickup)"},
    %{name: :address, type: :map, description: "Location address (for pickup)"}
  ]

  @method_response_fields [
    %{name: :id, type: :string, required: true, description: "Method identifier"},
    %{
      name: :type,
      type: @method_type_type,
      required: true,
      description: "Fulfillment method type"
    },
    %{name: :line_item_ids, type: {:array, :string}, description: "Line items"},
    %{name: :destinations, type: {:array, :map}, description: "Available destinations"},
    %{name: :selected_destination_id, type: :string, description: "Selected destination"},
    %{name: :groups, type: {:array, :map}, description: "Fulfillment groups with options"}
  ]

  @available_method_response_fields [
    %{name: :type, type: @method_type_type, required: true, description: "Method type"},
    %{name: :line_item_ids, type: {:array, :string}, description: "Available line items"}
  ]

  @fulfillment_response_fields [
    %{name: :methods, type: {:array, :map}, description: "Fulfillment methods with options"},
    %{name: :available_methods, type: {:array, :map}, description: "Availability per method type"}
  ]

  # ============================================================================
  # Configuration Schemas
  # ============================================================================

  @merchant_config_fields [
    %{
      name: :allows_multi_destination,
      type: :boolean,
      default: false,
      description: "Whether multiple destinations per method type are allowed"
    },
    %{
      name: :allows_method_combinations,
      type: :boolean,
      default: false,
      description: "Whether different method types can be combined"
    }
  ]

  @platform_config_fields [
    %{
      name: :supports_multi_group,
      type: :boolean,
      default: false,
      description: "Whether platform supports multiple groups per method"
    }
  ]

  # ============================================================================
  # Public API
  # ============================================================================

  @doc "Returns fulfillment request field definitions."
  def request_fields, do: @fulfillment_request_fields

  @doc "Returns fulfillment response field definitions."
  def response_fields, do: @fulfillment_response_fields

  @doc "Returns method request field definitions."
  def method_request_fields, do: @method_request_fields

  @doc "Returns method response field definitions."
  def method_response_fields, do: @method_response_fields

  @doc "Returns destination request field definitions."
  def destination_request_fields, do: @destination_request_fields

  @doc "Returns destination response field definitions."
  def destination_response_fields, do: @destination_response_fields

  @doc "Returns group request field definitions."
  def group_request_fields, do: @group_request_fields

  @doc "Returns group response field definitions."
  def group_response_fields, do: @group_response_fields

  @doc "Returns option response field definitions."
  def option_response_fields, do: @option_response_fields

  @doc "Returns available method request field definitions."
  def available_method_request_fields, do: @available_method_request_fields

  @doc "Returns available method response field definitions."
  def available_method_response_fields, do: @available_method_response_fields

  @doc "Returns merchant configuration field definitions."
  def merchant_config_fields, do: @merchant_config_fields

  @doc "Returns platform configuration field definitions."
  def platform_config_fields, do: @platform_config_fields

  @doc "Returns address field definitions."
  def address_fields, do: @address_fields

  @doc "Returns pickup location field definitions."
  def pickup_location_fields, do: @pickup_location_fields

  @doc "Returns total field definitions for fulfillment options."
  def total_fields, do: @total_fields

  @doc "Returns the supported method types."
  def method_types, do: @method_type_values

  @doc "Returns the supported destination types."
  def destination_types, do: @destination_type_values

  @doc "Returns default merchant fulfillment configuration."
  def default_merchant_config do
    %{
      "allows_multi_destination" => false,
      "allows_method_combinations" => false
    }
  end

  @doc "Returns default platform fulfillment configuration."
  def default_platform_config do
    %{
      "supports_multi_group" => false
    }
  end
end
