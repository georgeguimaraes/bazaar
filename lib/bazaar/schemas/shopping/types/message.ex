defmodule Bazaar.Schemas.Shopping.Types.Message do
  @moduledoc """
  Message
  
  Container for error, warning, or info messages.
  
  Generated from: message.json
  """
  alias Bazaar.Schemas.Shopping.Types.MessageError
  alias Bazaar.Schemas.Shopping.Types.MessageInfo
  alias Bazaar.Schemas.Shopping.Types.MessageWarning

  @variants [
    Bazaar.Schemas.Shopping.Types.MessageError,
    Bazaar.Schemas.Shopping.Types.MessageWarning,
    Bazaar.Schemas.Shopping.Types.MessageInfo
  ]
  @doc "Returns the variant modules for this union type."
  def variants do
    @variants
  end

  @doc "Casts params to one of the variant types."
  def cast(params) when is_map(params) do
    case params do
      %{"type" => "error"} -> MessageError.new(params)
      %{"type" => "warning"} -> MessageWarning.new(params)
      %{"type" => "info"} -> MessageInfo.new(params)
      _ -> {:error, :unknown_variant}
    end
  end
end
