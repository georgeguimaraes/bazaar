defmodule Bazaar.BuyerConsentTest do
  use ExUnit.Case, async: true

  alias Bazaar.BuyerConsent

  @legacy %{"marketing" => true, "analytics" => false, "sale_of_data" => false}

  @purposes %{
    "dev.ucp.consent.marketing" => %{
      "granted" => true,
      "source" => "platform",
      "description" => "Marketing communications"
    },
    "dev.ucp.consent.analytics" => %{
      "granted" => false,
      "source" => "platform",
      "description" => "Analytics and performance tracking"
    },
    "dev.ucp.consent.sale_or_sharing" => %{
      "granted" => false,
      "source" => "platform",
      "description" => "Sale or sharing of personal data"
    }
  }

  test "turns the 2026-04-08 booleans into platform-asserted purposes" do
    assert BuyerConsent.legacy?(@legacy)
    assert BuyerConsent.normalize(@legacy) == @purposes
  end

  test "passes a purpose map through and ignores unknown legacy keys" do
    refute BuyerConsent.legacy?(@purposes)
    assert BuyerConsent.normalize(@purposes) == @purposes

    assert BuyerConsent.normalize(%{"marketing" => true, "loyalty_card" => true}) ==
             Map.take(@purposes, ["dev.ucp.consent.marketing"])
  end

  test "renders the booleans a 2026-04-08 platform expects" do
    assert BuyerConsent.legacy(@purposes) == @legacy
  end
end
