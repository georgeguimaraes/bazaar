defmodule Bazaar.Schemas.Shopping.Types.Message do
  @moduledoc """
  Message
  
  Container for error, warning, or info messages.
  
  Generated from: message.json
  """
  import Ecto.Changeset

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
      %{"type" => "error"} -> Bazaar.Schemas.Shopping.Types.MessageError.new(params)
      %{"type" => "warning"} -> Bazaar.Schemas.Shopping.Types.MessageWarning.new(params)
      %{"type" => "info"} -> Bazaar.Schemas.Shopping.Types.MessageInfo.new(params)
      _ -> {:error, :unknown_variant}
    end
  end
end