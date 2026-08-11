defmodule Aesir.ZoneServer.Mmo.Skills.AcolytePriestMonkRequirementsTest do
  use ExUnit.Case, async: true

  @requirements %{
    Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDecagi => [],
    Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal => [],
    Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolylight => [],
    Aesir.ZoneServer.Mmo.Skills.Acolyte.AlIncagi => [],
    Aesir.ZoneServer.Mmo.Skills.Acolyte.AlPneuma => [],
    Aesir.ZoneServer.Mmo.Skills.Acolyte.AlTeleport => [],
    Aesir.ZoneServer.Mmo.Skills.Priest.PrKyrie => [],
    Aesir.ZoneServer.Mmo.Skills.Priest.PrLexaeterna => [],
    Aesir.ZoneServer.Mmo.Skills.Priest.PrLexdivina => [],
    Aesir.ZoneServer.Mmo.Skills.Priest.PrSanctuary => [],
    Aesir.ZoneServer.Mmo.Skills.Priest.PrStrecovery => [:player_state],
    Aesir.ZoneServer.Mmo.Skills.Monk.MoBalkyoung => [],
    Aesir.ZoneServer.Mmo.Skills.Monk.MoBodyrelocation => [],
    Aesir.ZoneServer.Mmo.Skills.Monk.MoExtremityfist => [],
    Aesir.ZoneServer.Mmo.Skills.Monk.MoFingeroffensive => [],
    Aesir.ZoneServer.Mmo.Skills.Monk.MoInvestigate => []
  }

  test "mob-row skills declare their caster requirements" do
    for {module, requires} <- @requirements do
      assert module.definition().requires == requires
    end
  end
end
