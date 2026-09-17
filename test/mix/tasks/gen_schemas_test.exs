defmodule Mix.Tasks.Bazaar.Gen.SchemasTest do
  use ExUnit.Case, async: true

  @schemas_dir :code.priv_dir(:bazaar) |> Path.join("ucp_schemas/2026-08-25")

  # The roots bazaar generates from: its handler surface plus the profile documents.
  @roots ~w(*.json shopping/cart*.json shopping/catalog*.json shopping/checkout*.json shopping/order*.json shopping/fulfillment*.json shopping/discount*.json shopping/buyer_consent*.json transports/*.json)

  test "the ref closure pulls in what the roots reference and nothing else" do
    closure = Mix.Tasks.Bazaar.Gen.Schemas.closure(@schemas_dir, @roots)

    assert "shopping/checkout_resp.json" in closure
    assert "common/types/totals_resp.json" in closure, "reached from checkout totals"
    assert "common/types/message_error.json" in closure, "reached from checkout messages"
    assert "profile.json" in closure

    # Cart and catalog ride in through the extension $defs of buyer consent,
    # discount and fulfillment; what the roots never reach stays out.
    refute "common/location_search_resp.json" in closure
    refute "common/loyalty_resp.json" in closure
    refute "common/payment_terms_resp.json" in closure
    refute "common/identity_linking.json" in closure
  end
end
