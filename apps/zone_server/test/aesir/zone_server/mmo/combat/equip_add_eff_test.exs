defmodule Aesir.ZoneServer.Mmo.Combat.EquipAddEffTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.AutoTriggerFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.EquipAddEff

  defp register(pairs) do
    bonuses =
      Enum.map(pairs, fn
        {dest, value, duration} -> %{EquipAddEff.bonus(dest, value) | duration: duration}
        {dest, value} -> EquipAddEff.bonus(dest, value)
      end)

    EquipAddEff.register(%{}, bonuses)
  end

  test "a repeated status and flag adds its chances and keeps the longer duration" do
    entries =
      register([
        {{:add_eff, :sc_stun}, 100, 9_000},
        {{:add_eff, :sc_blind}, 50},
        {{:arrow_add_eff, :sc_stun}, 30, 2_000}
      ])
      |> EquipAddEff.entries(:attack)

    assert [%{sc: :sc_stun, rate: 100, arrow_rate: 30, duration: 9_000}, %{sc: :sc_blind}] =
             entries
  end

  test "the same status with another flag is a separate entry" do
    magic = BattleFlags.fill_trigger(AutoTriggerFlag.id(:magic))

    entries =
      register([{{:add_eff, :sc_stun}, 100}, {{:add_eff, {:sc_stun, magic}}, 100}])
      |> EquipAddEff.entries(:attack)

    assert length(entries) == 2
  end

  test "bAddEff2 names its wearer; an unflagged bAddEff targets the enemy with weapon attacks" do
    [enemy, wearer] =
      register([{{:add_eff, :sc_stun}, 100}, {{:add_eff2, :sc_stun}, 100}])
      |> EquipAddEff.entries(:attack)

    assert (enemy.flag &&& AutoTriggerFlag.id(:target)) != 0
    assert (enemy.flag &&& AutoTriggerFlag.id(:weapon)) != 0
    assert (wearer.flag &&& AutoTriggerFlag.id(:self)) != 0
    assert (wearer.flag &&& AutoTriggerFlag.id(:target)) == 0
  end

  test "an unset duration is the status's lookup default, a status without one has none" do
    [stun, unknown] =
      register([{{:add_eff, :sc_stun}, 100}, {{:add_eff, :sc_hiding}, 100}])
      |> EquipAddEff.entries(:attack)

    assert stun.duration == if(GameMode.mode() == :renewal, do: 4_500, else: 5_000)
    assert unknown.duration == 0
  end

  test "when-hit and on-skill bonuses keep their own lists; on-skill merges per skill" do
    modifiers =
      register([
        {{:add_eff_when_hit, :sc_freeze}, 100},
        {{:add_eff_on_skill, 62, :sc_stun}, 100},
        {{:add_eff_on_skill, 7, :sc_stun}, 100},
        {{:add_eff_on_skill, 62, :sc_stun}, 50}
      ])

    assert [%{sc: :sc_freeze}] = EquipAddEff.entries(modifiers, :when_hit)

    assert [%{skill_id: 62, rate: 150}, %{skill_id: 7, rate: 100}] =
             EquipAddEff.entries(modifiers, :on_skill)
  end
end
