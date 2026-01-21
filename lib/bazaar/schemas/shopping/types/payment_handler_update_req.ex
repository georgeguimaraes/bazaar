defmodule Bazaar.Schemas.Shopping.Types.PaymentHandlerUpdateReq do
  @moduledoc """
  Payment Handler Update Request
  
  Generated from: payment_handler.update_req.json
  """
  @fields []
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
  end
end