defmodule Bazaar.Schemas.Shopping.Types.Link do
  @moduledoc """
  Link
  
  Generated from: link.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :title,
      type: :string,
      description:
        "Optional display text for the link. When provided, use this instead of generating from type."
    },
    %{
      name: :type,
      type: :string,
      description:
        "Type of link. Well-known values: `privacy_policy`, `terms_of_service`, `refund_policy`, `shipping_policy`, `faq`. Consumers SHOULD handle unknown values gracefully by displaying them using the `title` field or omitting the link."
    },
    %{
      name: :url,
      type: :string,
      description: "The actual URL pointing to the content to be displayed."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:type, :url])
  end
end