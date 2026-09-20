defmodule Mix.Tasks.Bazaar.Gen.SchemasTest do
  use ExUnit.Case, async: true

  @schemas_dir :code.priv_dir(:bazaar) |> Path.join("ucp_schemas/2026-08-25")

  # The roots bazaar generates from: its handler surface plus the profile documents.
  @roots ~w(*.json shopping/cart*.json shopping/catalog*.json shopping/checkout*.json shopping/order*.json shopping/fulfillment*.json shopping/discount*.json shopping/buyer_consent*.json)

  test "generates a module for an array root with inline object items, skips arrays of refs" do
    dir = Path.join(System.tmp_dir!(), "bazaar_gen_schemas_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    File.write!(
      Path.join(dir, "entries.json"),
      JSON.encode!(%{
        "$id" => "https://example.test/entries.json",
        "type" => "array",
        "items" => %{"type" => "object", "properties" => %{"amount" => %{"type" => "integer"}}}
      })
    )

    File.write!(
      Path.join(dir, "links.json"),
      JSON.encode!(%{
        "$id" => "https://example.test/links.json",
        "type" => "array",
        "items" => %{"$ref" => "entries.json"}
      })
    )

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Mix.Tasks.Bazaar.Gen.Schemas.run([
          dir,
          "--dry-run",
          "--output-dir",
          Path.join(dir, "out")
        ])
      end)

    assert output =~ ~r/entries\.json -> .*entries\.ex/
    assert output =~ ~r/Skipped links\.json/
  end

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
