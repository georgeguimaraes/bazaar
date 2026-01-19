defmodule Ucphi.CurrenciesTest do
  use ExUnit.Case, async: true

  alias Ucphi.Currencies

  describe "codes/0" do
    test "returns a list of currency codes" do
      codes = Currencies.codes()

      assert is_list(codes)
      assert length(codes) > 0
    end

    test "includes major world currencies" do
      codes = Currencies.codes()

      assert "USD" in codes
      assert "EUR" in codes
      assert "GBP" in codes
      assert "JPY" in codes
      assert "CNY" in codes
      assert "CAD" in codes
      assert "AUD" in codes
      assert "CHF" in codes
    end

    test "includes common regional currencies" do
      codes = Currencies.codes()

      # Americas
      assert "BRL" in codes
      assert "MXN" in codes
      assert "ARS" in codes

      # Europe
      assert "SEK" in codes
      assert "NOK" in codes
      assert "PLN" in codes
      assert "CZK" in codes

      # Asia
      assert "INR" in codes
      assert "KRW" in codes
      assert "SGD" in codes
      assert "HKD" in codes
      assert "THB" in codes

      # Middle East
      assert "AED" in codes
      assert "SAR" in codes
      assert "ILS" in codes

      # Africa
      assert "ZAR" in codes
      assert "NGN" in codes
      assert "EGP" in codes

      # Oceania
      assert "NZD" in codes
      assert "FJD" in codes
    end

    test "all codes are uppercase 3-letter strings" do
      codes = Currencies.codes()

      for code <- codes do
        assert is_binary(code)
        assert String.length(code) == 3
        assert code == String.upcase(code)
      end
    end

    test "contains no duplicates" do
      codes = Currencies.codes()
      unique_codes = Enum.uniq(codes)

      assert length(codes) == length(unique_codes)
    end

    test "codes are sorted alphabetically" do
      codes = Currencies.codes()
      sorted_codes = Enum.sort(codes)

      assert codes == sorted_codes
    end
  end

  describe "valid?/1" do
    test "returns true for valid currency codes" do
      assert Currencies.valid?("USD") == true
      assert Currencies.valid?("EUR") == true
      assert Currencies.valid?("GBP") == true
      assert Currencies.valid?("JPY") == true
    end

    test "returns false for invalid currency codes" do
      assert Currencies.valid?("INVALID") == false
      assert Currencies.valid?("XXX") == false
      assert Currencies.valid?("ABC") == false
      assert Currencies.valid?("US") == false
      assert Currencies.valid?("USDD") == false
    end

    test "returns false for lowercase currency codes" do
      assert Currencies.valid?("usd") == false
      assert Currencies.valid?("eur") == false
      assert Currencies.valid?("Usd") == false
    end

    test "returns false for empty string" do
      assert Currencies.valid?("") == false
    end

    test "returns false for nil" do
      assert Currencies.valid?(nil) == false
    end

    test "returns false for atoms" do
      assert Currencies.valid?(:USD) == false
      assert Currencies.valid?(:usd) == false
    end

    test "returns false for integers" do
      assert Currencies.valid?(840) == false
      assert Currencies.valid?(978) == false
    end

    test "returns false for lists" do
      assert Currencies.valid?(["USD"]) == false
      assert Currencies.valid?([]) == false
    end

    test "returns false for maps" do
      assert Currencies.valid?(%{code: "USD"}) == false
      assert Currencies.valid?(%{}) == false
    end

    test "validates all codes from codes/0" do
      for code <- Currencies.codes() do
        assert Currencies.valid?(code) == true,
               "Expected #{inspect(code)} to be valid"
      end
    end
  end

  describe "integration with CheckoutSession schema" do
    test "valid currencies are accepted by CheckoutSession" do
      for currency <- ["USD", "EUR", "GBP", "JPY", "CAD"] do
        changeset =
          Ucphi.Schemas.CheckoutSession.new(%{
            "currency" => currency,
            "line_items" => [%{"item" => %{"id" => "ABC"}, "quantity" => 1}],
            "payment" => %{}
          })

        assert changeset.valid?,
               "Expected currency #{currency} to be accepted"
      end
    end

    test "invalid currencies are rejected by CheckoutSession" do
      changeset =
        Ucphi.Schemas.CheckoutSession.new(%{
          "currency" => "INVALID",
          "line_items" => [%{"item" => %{"id" => "ABC"}, "quantity" => 1}],
          "payment" => %{}
        })

      refute changeset.valid?

      errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
      assert errors[:currency] == ["is invalid"]
    end
  end
end
