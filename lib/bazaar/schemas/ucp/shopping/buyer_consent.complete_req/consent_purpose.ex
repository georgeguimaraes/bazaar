defmodule Bazaar.Schemas.Shopping.BuyerConsentCompleteReq.ConsentPurpose do
  @moduledoc """
  Schema

  A buyer's consent decision for a purpose (e.g., marketing, analytics). Carries the current binary state, its source (business default or platform-captured buyer decision), human-readable context, and optional refinements scoping the decision to specific channels, vendors, or programs.

  Generated from: buyer_consent.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @source_values [:business, :platform]
  @doc "Returns the description for a field, if available."
  def field_description(:granted) do
    "Whether consent has been granted for this purpose. The `source` field identifies who asserted this state (business default or platform-captured buyer preference)."
  end

  def field_description(:segments) do
    "Optional refinements scoping this purpose to specific channels, vendors, or programs. Keys are reverse-DNS identifiers. UCP currently defines two well-known segment identifiers under `dev.ucp.consent.marketing`: `dev.ucp.consent.marketing.email`, `dev.ucp.consent.marketing.sms`. Other segments follow vendor or merchant reverse-DNS conventions."
  end

  def field_description(:source) do
    "Identifies the party that asserted the current `granted` value. `business` means the value reflects the business's default policy; `platform` means the value reflects an explicit buyer decision captured by the platform."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:granted, :boolean)
    field(:segments, :map)
    field(:source, Ecto.Enum, values: @source_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:granted, :segments, :source])
    |> validate_required([:granted, :source])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
