defmodule Bazaar.Schemas.Shopping.Types.MessageError do
  @moduledoc """
  Message Error
  
  Generated from: message_error.json
  """
  import Ecto.Changeset
  @content_type_values [:plain, :markdown]
  @content_type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @content_type_values)
  @severity_values [:recoverable, :requires_buyer_input, :requires_buyer_review]
  @severity_type Ecto.ParameterizedType.init(Ecto.Enum, values: @severity_values)
  @type_values [:error]
  @type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @type_values)
  @fields [
    %{
      name: :code,
      type: :string,
      description:
        "Error code. Possible values include: missing, invalid, out_of_stock, payment_declined, requires_sign_in, requires_3ds, requires_identity_linking. Freeform codes also allowed."
    },
    %{name: :content, type: :string, description: "Human-readable message."},
    %{
      name: :content_type,
      type: @content_type_type,
      description: "Content format, default = plain."
    },
    %{
      name: :path,
      type: :string,
      description: "RFC 9535 JSONPath to the component the message refers to (e.g., $.items[1])."
    },
    %{
      name: :severity,
      type: @severity_type,
      description:
        "Declares who resolves this error. 'recoverable': agent can fix via API. 'requires_buyer_input': merchant requires information their API doesn't support collecting programmatically (checkout incomplete). 'requires_buyer_review': buyer must authorize before order placement due to policy, regulatory, or entitlement rules (checkout complete). Errors with 'requires_*' severity contribute to 'status: requires_escalation'."
    },
    %{name: :type, type: @type_type, description: "Message type discriminator."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:type, :code, :content, :severity])
  end
end