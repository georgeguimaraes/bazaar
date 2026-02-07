defmodule Bazaar.Schemas.Profile do
  @moduledoc """
  UCP Discovery Profile

  Schema for UCP discovery profiles. Business profiles are hosted at /.well-known/ucp; platform profiles are hosted at URIs advertised in request headers.

  Generated from: profile.json
  """
  alias Bazaar.Schemas.Profile.BusinessProfile
  alias Bazaar.Schemas.Profile.PlatformProfile
  @variants [Bazaar.Schemas.Profile.PlatformProfile, Bazaar.Schemas.Profile.BusinessProfile]
  @doc "Returns the variant modules for this union type."
  def variants do
    @variants
  end

  @doc "Casts params to one of the variant types."
  def cast(params) when is_map(params) do
    Enum.find_value([PlatformProfile, BusinessProfile], {:error, :no_matching_variant}, fn mod ->
      case mod.new(params) do
        %Ecto.Changeset{valid?: true} = changeset -> {:ok, changeset}
        _ -> nil
      end
    end)
  end
end
