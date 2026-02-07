defmodule Bazaar.Message do
  @moduledoc """
  Business logic helpers for UCP Messages (errors, warnings, info).

  Messages communicate session state to agents and buyers. Each message
  has a type discriminator that determines which fields are applicable.

  ## Message Types

  - `:error` - Indicates a problem that prevents checkout completion
  - `:warning` - Indicates a potential issue that may need attention
  - `:info` - Provides informational context

  ## Example

      # Error message
      Bazaar.Message.error(%{
        "code" => "out_of_stock",
        "content" => "Item SKU-123 is no longer available",
        "severity" => "recoverable",
        "path" => "$.line_items[0]"
      })

      # Warning message
      Bazaar.Message.warning(%{
        "code" => "price_changed",
        "content" => "Price has increased since item was added"
      })
  """

  import Ecto.Changeset

  alias Bazaar.Schemas.Shopping.Types.MessageError
  alias Bazaar.Schemas.Shopping.Types.MessageInfo
  alias Bazaar.Schemas.Shopping.Types.MessageWarning

  @type_values [:error, :warning, :info]
  @severity_values [:recoverable, :requires_buyer_input, :requires_buyer_review]

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

  @doc "Returns the message type values."
  def type_values, do: @type_values

  @doc "Returns the severity values."
  def severity_values, do: @severity_values

  @doc "Returns well-known error codes from the UCP spec."
  def well_known_codes, do: @well_known_codes

  @doc """
  Creates an error message changeset.

  ## Required Fields

  - `code` - Error code identifier
  - `content` - User-facing error description
  - `severity` - Resolution responsibility level
  """
  def error(params \\ %{}) do
    params = Map.put(params, "type", "error")
    MessageError.new(params)
  end

  @doc """
  Creates a warning message changeset.

  ## Required Fields

  - `code` - Warning code identifier
  - `content` - User-facing warning description
  """
  def warning(params \\ %{}) do
    params = Map.put(params, "type", "warning")

    MessageWarning.new(params)
    |> validate_required([:code, :content])
  end

  @doc """
  Creates an info message changeset.

  ## Required Fields

  - `code` - Info code identifier
  - `content` - User-facing info description
  """
  def info(params \\ %{}) do
    params = Map.put(params, "type", "info")

    MessageInfo.new(params)
    |> validate_required([:code, :content])
  end

  @doc """
  Parses a message from params, determining type from the `type` field.

  This implements oneOf-like behavior by routing to the appropriate
  schema based on the discriminator field.
  """
  def parse(%{"type" => "error"} = params), do: {:ok, error(params)}
  def parse(%{"type" => "warning"} = params), do: {:ok, warning(params)}
  def parse(%{"type" => "info"} = params), do: {:ok, info(params)}
  def parse(%{"type" => _}), do: {:error, "type must be one of: error, warning, info"}
  def parse(%{} = _params), do: {:error, "type is required"}

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
          {:ok, %{valid?: true} = changeset} ->
            {:ok, Ecto.Changeset.apply_changes(changeset)}

          {:ok, %{valid?: false} = changeset} ->
            {:error, {idx, Bazaar.Errors.from_changeset(changeset)}}

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
