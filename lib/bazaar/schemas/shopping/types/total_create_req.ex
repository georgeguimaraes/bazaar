defmodule Bazaar.Schemas.Shopping.Types.TotalCreateReq do
  @moduledoc """
  Total Create Request
  
  Generated from: total.create_req.json
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