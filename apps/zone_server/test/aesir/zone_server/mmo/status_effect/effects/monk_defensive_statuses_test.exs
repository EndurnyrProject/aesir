defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MonkDefensiveStatusesTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ExplosionSpirits
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SteelBody
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(Resistance)
    Mimic.copy(UnitRegistry)

    stub(UnitRegistry, :get_unit_info, fn :player, player_id ->
      {:ok,
       %{
         unit_id: player_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{max_hp: 1_000, max_sp: 100, hp: 800, sp: 80}
       }}
    end)

    stub(Resistance, :roll_success, fn _ -> true end)
    :ok
  end

  test "Fury adds the verified internal critical bonus for its level" do
    entry = %StatusEntry{type: :sc_explosionspirits, val1: 3, state: %{}}

    assert ExplosionSpirits.modifiers(entry, %{}) == %{
             critical: 150,
             regen_interval_multiplier: 2
           }
  end

  test "Mental Strength reduces positive incoming damage and preserves non-positive values" do
    entry = %StatusEntry{type: :sc_steelbody, state: %{}}

    assert {:ok, 1, ^entry} = SteelBody.absorb_damage({:player, 1}, entry, %{damage: 9}, %{})
    assert {:ok, 10, ^entry} = SteelBody.absorb_damage({:player, 1}, entry, %{damage: 100}, %{})
    assert {:ok, 0, ^entry} = SteelBody.absorb_damage({:player, 1}, entry, %{damage: 0}, %{})
  end

  test "Mental Strength exposes its fixed movement and attack-delay modifiers" do
    entry = %StatusEntry{type: :sc_steelbody, state: %{}}

    assert SteelBody.modifiers(entry, %{}) == %{walk_speed_override: 200, aspd_penalty_rate: 250}
    assert :prevents_skills in SteelBody.metadata().properties
  end

  test "Mental Strength restricts casts and all effects disappear on removal" do
    player_id = 1000

    assert :ok =
             Interpreter.apply_status(:player, player_id, :sc_steelbody,
               caster_id: player_id,
               duration: 30_000
             )

    refute Interpreter.can_use_skill?(:player, player_id)

    assert Interpreter.get_all_modifiers(:player, player_id) == %{
             walk_speed_override: 200,
             aspd_penalty_rate: 250
           }

    assert :ok = Interpreter.remove_status(:player, player_id, :sc_steelbody)

    assert Interpreter.can_use_skill?(:player, player_id)
    assert Interpreter.get_all_modifiers(:player, player_id) == %{}
  end

  test "Mental Strength reduces every positive combat damage type while zero passes through" do
    player_id = 1001

    assert :ok =
             Interpreter.apply_status(:player, player_id, :sc_steelbody,
               caster_id: player_id,
               duration: 30_000
             )

    assert 1 = Interpreter.absorb_damage(:player, player_id, 9, %{dmg_type: :physical})
    assert 10 = Interpreter.absorb_damage(:player, player_id, 100, %{dmg_type: :magic})
    assert 0 = Interpreter.absorb_damage(:player, player_id, 0, %{dmg_type: :misc})
  end
end
