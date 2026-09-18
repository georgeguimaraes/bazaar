defmodule Bazaar.Schemas.Common.Types.Policy do
  @moduledoc """
  Policy

  A durable business rule about the items in a response — return/refund terms, warranty, and the like — at the time of purchase. Every policy carries a `type` (an open reverse-DNS vocabulary) and a `description` so a platform can present it without understanding its type-specific fields; type-specific fields (gated by `type`) add structured context for platforms that model that type. Policies are reference data; the obligation to display a term to the buyer is carried by a `messages[]` warning whose `code` equals the policy `type` — see the Policies section of the specification.

  Generated from: policy.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Description

  @field_descriptions %{
    applies_to:
      "RFC 9535 JSONPath expressions identifying the nodes this policy applies to, relative to the embedding response root (e.g., `$.line_items[0]` in cart/checkout, `$.products[2]` in catalog). Each target covers the node it names and everything nested under it, so a target on a product also covers its variants. A singular query (RFC 9535 Section 2.3.5.1; name and index selectors only) names a single node; filters, wildcards, and slices match a set. When omitted, the policy applies to the entire response. When policies of the same `type` contest a node, the narrowest target wins and overrides the rest. See the Policies section for how specificity resolves.",
    description:
      "Human-readable policy summary in one or more formats (plain, markdown, html). Required on every policy so a platform can present it without understanding any type-specific fields. This is not the buyer-facing disclosure — display is compelled by a `messages[]` warning (see the Policies section).",
    type:
      "Policy type discriminator. Open reverse-DNS vocabulary. Well-known values: `dev.ucp.shopping.policy.return` (return terms), `dev.ucp.shopping.policy.warranty` (warranty terms). Businesses MAY define custom types in their own domain (e.g., `com.example.policy.price_match`). Platforms MUST tolerate unknown values.",
    url: "Optional link to the full policy document."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:applies_to, {:array, :string})
    field(:type, :string)
    field(:url, :string)
    embeds_one(:description, Description)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:applies_to, :type, :url])
    |> cast_embed(:description, required: true)
    |> validate_required([:type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
