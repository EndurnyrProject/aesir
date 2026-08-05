defmodule Aesir.ZoneServer.Mmo.Skills.SwordsmanKnightCrusaderRequirementsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobSkill.Denylist
  alias Aesir.ZoneServer.Mmo.Skill.Castability

  @requirements [
    {Aesir.ZoneServer.Mmo.Skills.Swordsman.SmBash, 5, []},
    {Aesir.ZoneServer.Mmo.Skills.Swordsman.SmEndure, 8, [:player_state]},
    {Aesir.ZoneServer.Mmo.Skills.Swordsman.SmMagnum, 7, [:player_state]},
    {Aesir.ZoneServer.Mmo.Skills.Swordsman.SmProvoke, 6, [:player_state]},
    {Aesir.ZoneServer.Mmo.Skills.Knight.KnAutocounter, 61, [:player_state]},
    {Aesir.ZoneServer.Mmo.Skills.Knight.KnBowlingbash, 62, []},
    {Aesir.ZoneServer.Mmo.Skills.Knight.KnBrandishspear, 57, []},
    {Aesir.ZoneServer.Mmo.Skills.Knight.KnPierce, 56, []},
    {Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearboomerang, 59, []},
    {Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearstab, 58, []},
    {Aesir.ZoneServer.Mmo.Skills.Knight.KnTwohandquicken, 60, []},
    {Aesir.ZoneServer.Mmo.Skills.Crusader.CrAutoguard, 249, []},
    {Aesir.ZoneServer.Mmo.Skills.Crusader.CrDevotion, 255, [:party]},
    {Aesir.ZoneServer.Mmo.Skills.Crusader.CrGrandcross, 254, []},
    {Aesir.ZoneServer.Mmo.Skills.Crusader.CrHolycross, 253, []},
    {Aesir.ZoneServer.Mmo.Skills.Crusader.CrReflectshield, 252, []},
    {Aesir.ZoneServer.Mmo.Skills.Crusader.CrShieldboomerang, 251, []},
    {Aesir.ZoneServer.Mmo.Skills.Crusader.CrShieldcharge, 250, []}
  ]

  test "mob-row skills preserve denylist castability" do
    for {module, id, requires} <- @requirements do
      definition = module.definition()
      expected = if Denylist.denied?(id), do: {:error, {:missing, requires}}, else: :ok

      assert definition.id == id
      assert definition.requires == requires
      assert Castability.check(definition, :mob) == expected
    end
  end
end
