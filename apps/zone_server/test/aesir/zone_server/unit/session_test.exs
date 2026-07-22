defmodule Aesir.ZoneServer.Unit.SessionTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Session

  test "knock_back/4 casts the landing cell to the given pid for a player" do
    assert :ok = Session.knock_back(:player, self(), 153, 150)

    assert_received {:"$gen_cast", {:movement, {:knocked_back, 153, 150}}}
  end

  test "knock_back/4 casts the landing cell to the given pid for a mob" do
    assert :ok = Session.knock_back(:mob, self(), 42, 7)

    assert_received {:"$gen_cast", {:movement, {:knocked_back, 42, 7}}}
  end
end
