defmodule Bazaar.Schemas.Shopping.Types.MessageWarning do
  @moduledoc """
  Message Warning
  
  Generated from: message_warning.json
  """
  import Ecto.Changeset
  @content_type_values [:plain, :markdown]
  @content_type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @content_type_values)
  @type_values [:warning]
  @type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @type_values)
  @fields [
    %{
      name: :code,
      type: :string,
      description:
        "Warning code. Machine-readable identifier for the warning type (e.g., final_sale, prop65, fulfillment_changed, age_restricted, etc.)."
    },
    %{
      name: :content,
      type: :string,
      description: "Human-readable warning message that MUST be displayed."
    },
    %{
      name: :content_type,
      type: @content_type_type,
      description: "Content format, default = plain."
    },
    %{
      name: :path,
      type: :string,
      description: "JSONPath (RFC 9535) to related field (e.g., $.line_items[0])."
    },
    %{name: :type, type: @type_type, description: "Message type discriminator."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:type, :code, :content])
  end
end