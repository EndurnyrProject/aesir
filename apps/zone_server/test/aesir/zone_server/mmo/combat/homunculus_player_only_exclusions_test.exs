defmodule Aesir.ZoneServer.Mmo.Combat.HomunculusPlayerOnlyExclusionsTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrShieldcharge

  test "Shield Charge requires player equipment but remains callable by mobs" do
    player = build(:player_state)
    mob = build(:mob_state)
    definition = CrShieldcharge.definition()

    assert {:error, :requires_shield} = CrShieldcharge.begin_attempt(player, :self, 1, definition)
    assert {:ok, _caster} = CrShieldcharge.begin_attempt(mob, :self, 1, definition)
  end
end
