defmodule Aesir.ZoneServer.Mmo.Skills.RemainingJobRequirementsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobSkill.Denylist
  alias Aesir.ZoneServer.Mmo.Skill.Castability

  @requirements [
    {Aesir.ZoneServer.Mmo.Skills.Thief.TfBacksliding, 150, true, false, [:player_state]},
    {Aesir.ZoneServer.Mmo.Skills.Thief.TfHiding, 51, true, false, [:player_state]},
    {Aesir.ZoneServer.Mmo.Skills.Thief.TfPoison, 52, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Thief.TfSprinklesand, 149, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Thief.TfThrowstone, 152, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Hunter.HtAnklesnare, 117, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmine, 122, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Hunter.HtClaymoretrap, 123, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Hunter.HtFlasher, 120, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Hunter.HtFreezingtrap, 121, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Hunter.HtLandmine, 116, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Hunter.HtSandman, 119, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Hunter.HtShockwave, 118, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Hunter.HtSkidtrap, 115, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Archer.AcChargearrow, 148, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Archer.AcDouble, 46, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Archer.AcShower, 47, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Merchant.McMammonite, 42, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAdrenaline, 111, false, true, [:player_state]},
    {Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsHammerfall, 110, false, true, [:player_state]},
    {Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsMaximize, 114, false, true, [:player_state]},
    {Aesir.ZoneServer.Mmo.Skills.Alchemist.AmAcidterror, 230, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Alchemist.AmCannibalize, 232, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Alchemist.AmDemonstration, 229, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPotionpitcher, 231, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Sage.SaDispell, 289, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Sage.SaLandprotector, 288, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Sage.SaSpellbreaker, 277, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Bard.BaFrostjoker, 318, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Bard.BaMusicalstrike, 316, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Dancer.DcScream, 326, false, false, []},
    {Aesir.ZoneServer.Mmo.Skills.Dancer.DcThrowarrow, 324, false, false, []}
  ]

  test "mob-row skills declare requirements matching safe mob castability" do
    for {module, id, denylisted?, crashes_for_mob?, requires} <- @requirements do
      definition = module.definition()

      expected =
        if denylisted? or crashes_for_mob?, do: {:error, {:missing, requires}}, else: :ok

      assert definition.id == id
      assert Denylist.denied?(id) == denylisted?
      assert definition.requires == requires
      assert Castability.check(definition, :mob) == expected
    end
  end
end
