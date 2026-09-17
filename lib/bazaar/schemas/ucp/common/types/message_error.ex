defmodule Bazaar.Schemas.Common.Types.MessageError do
  @moduledoc """
  Message Error

  Generated from: message_error.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @content_type_values [:plain, :markdown]
  @severity_values [:recoverable, :requires_buyer_input, :requires_buyer_review, :unrecoverable]
  @type_values [:error]
  @field_descriptions %{
    code:
      "Error code identifying the type of error. Standard errors are defined in capability specifications (see examples) and have standardized semantics; freeform codes are permitted.",
    content: "Human-readable message.",
    content_type: "Content format, default = plain.",
    path: "RFC 9535 JSONPath to the component the message refers to (e.g., $.line_items[0]).",
    severity:
      "Reflects the resource state and recommended action. 'recoverable': platform can resolve the condition in band, for example by modifying inputs or processing a related Action, and submit a new operation when needed. 'requires_buyer_input': merchant requires information their API doesn't support collecting programmatically (checkout incomplete). 'requires_buyer_review': buyer must authorize before order placement due to policy, regulatory, or entitlement rules. 'unrecoverable': no valid resource exists to act on, retry with new resource or inputs. Errors with 'requires_*' severity contribute to 'status: requires_escalation'.",
    type: "Message type discriminator."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:code, :string)
    field(:content, :string)
    field(:path, :string)
    field(:content_type, Ecto.Enum, values: @content_type_values)
    field(:severity, Ecto.Enum, values: @severity_values)
    field(:type, Ecto.Enum, values: @type_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:code, :content, :path, :content_type, :severity, :type])
    |> validate_required([:type, :code, :content, :severity])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
