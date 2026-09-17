defmodule Bazaar.Schemas.Common.Types.ConstraintExpression.ValueConstraint do
  @moduledoc """
  Schema

  A Value Constraint containing `enum`, `const`, or both.

  Generated from: constraint_expression.json
  """
  @variants []
  @doc "Returns the variant modules for this union type."
  def variants do
    @variants
  end

  @doc "Casts params to one of the variant types."
  def cast(params) when is_map(params) do
    Enum.find_value([], {:error, :no_matching_variant}, fn mod ->
      case mod.new(params) do
        %Ecto.Changeset{valid?: true} = changeset -> {:ok, changeset}
        _ -> nil
      end
    end)
  end
end
