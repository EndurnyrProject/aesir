defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.OverThrustTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.OverThrust
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(Config)
    Mimic.copy(ElementModifiers)
    Mimic.copy(RaceModifiers)
    Mimic.copy(SizeModifiers)
    Mimic.copy(ModifierCalculator)
    :ok
  end

  test "uses the rate supplied by each application" do
    for rate <- [5, 25, 50] do
      entry = %StatusEntry{type: :sc_overthrust, val1: rate, state: %{}}
      assert OverThrust.modifiers(entry, %{}) == %{atk_rate: rate}
    end
  end

  test "increases physical damage by the stored rate" do
    stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
    stub(RaceModifiers, :player_race, fn -> :human end)
    stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)

    attacker = CombatTestHelper.create_player_combatant()
    defender = CombatTestHelper.create_mob_combatant(def: 0)

    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
    :rand.seed(:exsss, {1, 2, 3})
    {:ok, base} = DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

    over_thrust = OverThrust.modifiers(%StatusEntry{val1: 25, state: %{}}, %{})

    stub(ModifierCalculator, :get_all_modifiers, fn
      :player, 1001 -> over_thrust
      _, _ -> %{}
    end)

    :rand.seed(:exsss, {1, 2, 3})
    {:ok, boosted} = DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

    assert boosted.damage == div(base.damage * 125, 100)
  end

  test "never contributes a weapon-break rate at any level" do
    stub(Config, :natural_break_rate, fn -> 0 end)

    victim = %Stats{equipment: %Equipment{right_hand: 1101}, modifiers: %Modifiers{}}

    for rate <- [5, 10, 15, 20, 25] do
      attacker = %Stats{
        equipment: %Equipment{right_hand: 1101},
        modifiers: %Modifiers{equipment: OverThrust.modifiers(%StatusEntry{val1: rate}, %{})}
      }

      assert EquipBreak.resolve(attacker, {:player, 1002, victim}, rng: fn _ -> 1 end) == []
    end
  end

  test "declares the Over Thrust status metadata" do
    metadata = OverThrust.metadata()

    assert OverThrust.id() == :sc_overthrust
    assert metadata.icon == :overthrust
    assert :buff in metadata.properties
    assert :atk in metadata.calc_flags
    assert is_integer(Efst.id(metadata.icon))
  end
end
