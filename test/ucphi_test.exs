defmodule UcphiTest do
  use ExUnit.Case
  doctest Ucphi

  test "returns version" do
    assert Ucphi.version() == "0.1.0"
  end
end
