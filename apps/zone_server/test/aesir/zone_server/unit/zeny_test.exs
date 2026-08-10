defmodule Aesir.ZoneServer.Unit.ZenyTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Zeny

  test "returns the maximum zeny balance" do
    assert Zeny.max_zeny() == 1_000_000_000
  end
end
