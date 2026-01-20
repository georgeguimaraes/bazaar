defmodule Bazaar.Schemas.Shopping.Types.FulfillmentOptionResp do
  @moduledoc """
  Fulfillment Option Response
  
  A fulfillment option within a group (e.g., Standard Shipping $5, Express $15).
  
  Generated from: fulfillment_option_resp.json
  """
  import Ecto.Changeset

  @fields [
    %{name: :carrier, type: :string, description: "Carrier name (for shipping)."},
    %{
      name: :description,
      type: :string,
      description: "Complete context for buyer decision (e.g., 'Arrives Dec 12-15 via FedEx')."
    },
    %{
      name: :earliest_fulfillment_time,
      type: :utc_datetime,
      description: "Earliest fulfillment date."
    },
    %{name: :id, type: :string, description: "Unique fulfillment option identifier."},
    %{
      name: :latest_fulfillment_time,
      type: :utc_datetime,
      description: "Latest fulfillment date."
    },
    %{
      name: :title,
      type: :string,
      description: "Short label (e.g., 'Express Shipping', 'Curbside Pickup')."
    },
    %{
      name: :totals,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.TotalResp.fields(),
          with: &Function.identity/1
        ),
      description: "Fulfillment option totals breakdown."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:id, :title, :totals])
  end
end