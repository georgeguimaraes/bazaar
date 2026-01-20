defmodule Bazaar.Schemas.Shopping.Order.PlatformConfig do
  @moduledoc """
  Platform Order Config
  
  Platform's order capability configuration.
  
  Generated from: order.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :webhook_url,
      type: :string,
      description: "URL where merchant sends order lifecycle events (webhooks)."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:webhook_url])
  end
end