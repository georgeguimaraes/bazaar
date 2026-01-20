defmodule Bazaar.Schemas.Shopping.Types.MessageInfo do
  @moduledoc """
  Message Info
  
  Generated from: message_info.json
  """
  import Ecto.Changeset
  @content_type_values [:plain, :markdown]
  @content_type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @content_type_values)
  @type_values [:info]
  @type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @type_values)
  @fields [
    %{name: :code, type: :string, description: "Info code for programmatic handling."},
    %{name: :content, type: :string, description: "Human-readable message."},
    %{
      name: :content_type,
      type: @content_type_type,
      description: "Content format, default = plain."
    },
    %{
      name: :path,
      type: :string,
      description: "RFC 9535 JSONPath to the component the message refers to."
    },
    %{name: :type, type: @type_type, description: "Message type discriminator."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:type, :content])
  end
end