defmodule Ucphi.Schemas.Message do
  @moduledoc """
  Schema for UCP Messages (errors, warnings, info).

  Messages communicate session state to agents and buyers. Each message
  has a type discriminator that determines which fields are applicable.

  ## Message Types

  - `:error` - Indicates a problem that prevents checkout completion
  - `:warning` - Indicates a potential issue that may need attention
  - `:info` - Provides informational context

  ## Severity Levels (for errors)

  - `:recoverable` - Can be resolved automatically
  - `:requires_buyer_input` - Merchant API can't collect data programmatically
  - `:requires_buyer_review` - Buyer authorization needed for policy/regulatory compliance

  ## Example

      # Error message
      Ucphi.Schemas.Message.error(%{
        "code" => "out_of_stock",
        "content" => "Item SKU-123 is no longer available",
        "severity" => "recoverable",
        "path" => "$.line_items[0]"
      })

      # Warning message
      Ucphi.Schemas.Message.warning(%{
        "code" => "price_changed",
        "content" => "Price has increased since item was added"
      })

      # Info message
      Ucphi.Schemas.Message.info(%{
        "code" => "free_shipping",
        "content" => "You qualify for free shipping!"
      })
  """

  import Ecto.Changeset

  @type_values [:error, :warning, :info]
  @type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @type_values)

  @severity_values [:recoverable, :requires_buyer_input, :requires_buyer_review]
  @severity_type Ecto.ParameterizedType.init(Ecto.Enum, values: @severity_values)

  @content_type_values [:plain, :markdown]
  @content_type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @content_type_values)

  # Well-known error codes from UCP spec
  @well_known_codes [
    "missing",
    "invalid",
    "out_of_stock",
    "payment_declined",
    "requires_sign_in",
    "requires_3ds",
    "requires_identity_linking"
  ]

  @base_fields [
    %{name: :type, type: @type_type, description: "Message type: error, warning, or info"},
    %{name: :code, type: :string, description: "Error/message code identifier"},
    %{name: :path, type: :string, description: "JSONPath reference to related component"},
    %{name: :content_type, type: @content_type_type, default: :plain},
    %{name: :content, type: :string, description: "User-facing message description"}
  ]

  @error_fields @base_fields ++
                  [
                    %{
                      name: :severity,
                      type: @severity_type,
                      description: "Determines resolution responsibility"
                    }
                  ]

  @doc "Returns the base message field definitions."
  def base_fields, do: @base_fields

  @doc "Returns the error message field definitions (includes severity)."
  def error_fields, do: @error_fields

  @doc "Returns the message type values."
  def type_values, do: @type_values

  @doc "Returns the severity values."
  def severity_values, do: @severity_values

  @doc "Returns the content type values."
  def content_type_values, do: @content_type_values

  @doc "Returns well-known error codes from the UCP spec."
  def well_known_codes, do: @well_known_codes

  @doc """
  Creates an error message changeset.

  ## Required Fields

  - `code` - Error code identifier
  - `content` - User-facing error description
  - `severity` - Resolution responsibility level

  ## Example

      Ucphi.Schemas.Message.error(%{
        "code" => "payment_declined",
        "content" => "Your card was declined",
        "severity" => "requires_buyer_input"
      })
  """
  def error(params \\ %{}) do
    params = Map.put(params, "type", "error")

    Schemecto.new(@error_fields, params)
    |> validate_required([:type, :code, :content, :severity])
  end

  @doc """
  Creates a warning message changeset.

  ## Required Fields

  - `code` - Warning code identifier
  - `content` - User-facing warning description

  ## Example

      Ucphi.Schemas.Message.warning(%{
        "code" => "price_changed",
        "content" => "The price has changed since you added this item"
      })
  """
  def warning(params \\ %{}) do
    params = Map.put(params, "type", "warning")

    Schemecto.new(@base_fields, params)
    |> validate_required([:type, :code, :content])
  end

  @doc """
  Creates an info message changeset.

  ## Required Fields

  - `code` - Info code identifier
  - `content` - User-facing info description

  ## Example

      Ucphi.Schemas.Message.info(%{
        "code" => "loyalty_points",
        "content" => "You will earn 100 points with this purchase"
      })
  """
  def info(params \\ %{}) do
    params = Map.put(params, "type", "info")

    Schemecto.new(@base_fields, params)
    |> validate_required([:type, :code, :content])
  end

  @doc """
  Parses a message from params, determining type from the `type` field.

  This implements oneOf-like behavior by routing to the appropriate
  schema based on the discriminator field.

  ## Example

      Ucphi.Schemas.Message.parse(%{"type" => "error", "code" => "invalid", ...})
      # Routes to error/1

      Ucphi.Schemas.Message.parse(%{"type" => "warning", "code" => "price_changed", ...})
      # Routes to warning/1
  """
  def parse(params) when is_map(params) do
    type = params["type"] || params[:type]

    case type do
      t when t in ["error", :error] -> error(params)
      t when t in ["warning", :warning] -> warning(params)
      t when t in ["info", :info] -> info(params)
      nil -> {:error, "type is required"}
      _ -> {:error, "type must be one of: error, warning, info"}
    end
  end

  @doc """
  Validates a list of messages, routing each to the appropriate schema.

  Returns `{:ok, messages}` if all valid, or `{:error, errors}` with details.
  """
  def validate_messages(messages) when is_list(messages) do
    results =
      messages
      |> Enum.with_index()
      |> Enum.map(fn {msg, idx} ->
        case parse(msg) do
          %{valid?: true} = changeset ->
            {:ok, Ecto.Changeset.apply_changes(changeset)}

          %{valid?: false} = changeset ->
            {:error, {idx, Ucphi.Errors.from_changeset(changeset)}}

          {:error, reason} ->
            {:error, {idx, reason}}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, Enum.map(results, fn {:ok, msg} -> msg end)}
    else
      {:error, Enum.map(errors, fn {:error, e} -> e end)}
    end
  end
end
