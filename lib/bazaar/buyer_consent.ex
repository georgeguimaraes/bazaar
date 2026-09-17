defmodule Bazaar.BuyerConsent do
  @moduledoc """
  Buyer consent in the shape the spec defines.

  Since 2026-08-25 `buyer.consent` is a map keyed by reverse-DNS purpose, each
  purpose carrying `granted`, `source` (who asserted it) and `description`:

      %{
        "dev.ucp.consent.marketing" => %{"granted" => true, "source" => "platform", "description" => "..."},
        "dev.ucp.consent.analytics" => %{"granted" => false, "source" => "platform", "description" => "..."}
      }

  Platforms on the 2026-04-08 models still send the earlier booleans
  (`%{"marketing" => true, "analytics" => false, ...}`). `normalize/1` turns
  either into the purpose map so a handler stores one shape, and `legacy/1`
  turns it back for a platform that spoke booleans.
  """

  @purposes %{
    "marketing" => {"dev.ucp.consent.marketing", "Marketing communications"},
    "analytics" => {"dev.ucp.consent.analytics", "Analytics and performance tracking"},
    "preferences" => {"dev.ucp.consent.preferences", "Storing preferences"},
    "sale_of_data" => {"dev.ucp.consent.sale_or_sharing", "Sale or sharing of personal data"}
  }

  @legacy_keys Map.keys(@purposes)

  @doc "True when the consent map uses the pre-2026-08-25 boolean fields."
  def legacy?(consent) when is_map(consent) do
    Enum.any?(consent, fn {key, value} -> key in @legacy_keys and is_boolean(value) end)
  end

  def legacy?(_), do: false

  @doc """
  The purpose map for a consent object, whichever shape it arrived in.
  Boolean fields become platform-asserted purposes; a purpose map passes
  through untouched.
  """
  def normalize(consent) when is_map(consent) do
    if legacy?(consent) do
      for {key, granted} <- consent,
          is_boolean(granted),
          {:ok, {purpose, description}} <- [Map.fetch(@purposes, key)],
          into: %{} do
        {purpose, %{"granted" => granted, "source" => "platform", "description" => description}}
      end
    else
      consent
    end
  end

  def normalize(nil), do: nil

  @doc "The boolean fields a 2026-04-08 platform expects, from a purpose map."
  def legacy(purposes) when is_map(purposes) do
    for {key, {purpose, _description}} <- @purposes,
        %{"granted" => granted} <- [purposes[purpose]],
        into: %{},
        do: {key, granted}
  end
end
