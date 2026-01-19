defmodule BazaarTest do
  use ExUnit.Case
  doctest Bazaar

  test "returns version" do
    assert Bazaar.version() == "0.1.0"
  end
end
