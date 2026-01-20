defmodule Bazaar.Checkout do
  @moduledoc """
  Business logic helpers for UCP Checkout Sessions.

  This module provides utilities for working with checkout data,
  delegating schema validation to the generated `Bazaar.Schemas.Shopping.CheckoutResp`.

  ## Currency Conversion

      iex> Bazaar.Checkout.to_minor_units(19.99)
      1999

      iex> Bazaar.Checkout.to_major_units(1999)
      19.99
  """

  alias Bazaar.Schemas.Shopping.CheckoutResp

  # Delegate schema functions to the generated module
  defdelegate fields, to: CheckoutResp
  defdelegate new(params \\ %{}), to: CheckoutResp

  @doc """
  Converts an amount in major units (dollars) to minor units (cents).

  ## Example

      iex> Bazaar.Checkout.to_minor_units(19.99)
      1999
  """
  def to_minor_units(amount) when is_float(amount), do: round(amount * 100)
  def to_minor_units(amount) when is_integer(amount), do: amount * 100

  def to_minor_units(%Decimal{} = amount) do
    amount |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_integer()
  end

  @doc """
  Converts an amount in minor units (cents) to major units (dollars).

  ## Example

      iex> Bazaar.Checkout.to_major_units(1999)
      19.99
  """
  def to_major_units(amount) when is_integer(amount), do: amount / 100
end
