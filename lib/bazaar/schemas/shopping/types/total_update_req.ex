defmodule Bazaar.Schemas.Shopping.Types.TotalUpdateReq do
  @moduledoc """
  Total Update Request
  
  Generated from: total.update_req.json
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