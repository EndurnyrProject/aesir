defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MindBreakerTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.MindBreaker

  test "raises MATK 20% and cuts soft MDEF 12% per level" do
    assert MindBreaker.modifiers(%{val1: 3}, %{}) == %{matk_rate: 60, mdef2_rate: -36}
  end
end
