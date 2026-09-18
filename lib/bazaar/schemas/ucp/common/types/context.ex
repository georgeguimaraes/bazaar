defmodule Bazaar.Schemas.Common.Types.Context do
  @moduledoc """
  Context

  Provisional buyer signals for relevance and localization—not authoritative data. Businesses SHOULD use these values when verified inputs (e.g., shipping address) are absent, and MAY ignore or down-rank them if inconsistent with higher-confidence signals (authenticated account, risk detection) or regulatory constraints (export controls). Eligibility and policy enforcement MUST occur at checkout time using binding transaction data. Context SHOULD be non-identifying and can be disclosed progressively—coarse signals early, finer resolution as the session progresses. Higher-resolution data (shipping address, billing address) supersedes context.

  Generated from: context.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    address_country:
      "The country, as a 2-letter ISO 3166-1 alpha-2 code (e.g. \"US\"). A 3-letter alpha-3 code or full country name MAY also be used.",
    address_region:
      "The first-level administrative region within the country (e.g. a state or province such as California).",
    currency:
      "Preferred currency (ISO 4217, e.g., 'EUR', 'USD'). Businesses determine presentment currency from context and authoritative signals; this hint MAY inform selection in multi-currency markets. Also serves as the denomination for price filter values — platforms SHOULD include this field when sending price filters. Response prices include explicit currency confirming the resolution.",
    eligibility:
      "Buyer claims about eligible benefits such as loyalty membership, payment instrument perks, and similar. Recognized claims MAY inform the Business response (e.g., member-only product availability, adjusted pricing in catalog, provisional discounts at cart or checkout). Businesses MUST ignore unrecognized values without error. Values MUST use reverse-domain naming (e.g., 'com.example.loyalty_gold', 'org.school.student') and MUST be non-identifying.",
    intent:
      "Background context describing buyer's intent (e.g., 'looking for a gift under $50', 'need something durable for outdoor use'). Informs relevance, recommendations, and personalization.",
    language:
      "Preferred language for content. Use IETF BCP 47 language tags (e.g., 'en', 'fr-CA', 'zh-Hans'). For REST, equivalent to Accept-Language header—platforms SHOULD fall back to Accept-Language when this field is absent; when provided, overrides Accept-Language. Businesses MAY return content in a different language if unavailable.",
    location:
      "Stable, opaque identifier for a Location in the Business's namespace. This provisional, non-binding hint is distinct from the Buyer's locality. The operation specification or an active capability/extension defines its effects. A common example in retail shopping is the default home store ID selected and saved by the user when purchasing groceries.",
    payment:
      "Buyer-preferred payment handlers in priority order (most preferred first). Each entry names a handler advertised in the Business profile's `ucp.payment_handlers`, optionally narrowed to preferred instrument types. The Business SHOULD use it to preselect or prioritize the handler (and type, when given) and MAY ignore unavailable or ineligible entries; unrecognized values MUST be ignored without error.",
    postal_code: "The postal code (e.g. \"94043\")."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:address_country, :string)
    field(:address_region, :string)
    field(:currency, :string)
    field(:eligibility, {:array, :string})
    field(:intent, :string)
    field(:language, :string)
    field(:location, :string)
    field(:payment, {:array, :map})
    field(:postal_code, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :address_country,
      :address_region,
      :currency,
      :eligibility,
      :intent,
      :language,
      :location,
      :payment,
      :postal_code
    ])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
