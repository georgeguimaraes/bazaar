defmodule Bazaar.Schemas.Shopping.Types.PaymentHandlerCreateReq do
  @moduledoc """
  Payment Handler Create Request
  
  Generated from: payment_handler.create_req.json
  """
  import Ecto.Changeset
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