defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgSpecialsingerTest do
  use ExUnit.Case, async: true
  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skills.Clown.CgSpecialsinger
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "fatigue allows its cure, which removes the skill lock" do
    caster = PlayerStateFixture.build(%{character_id: 17, stats: %{combat_stats: %CombatStats{}}})
    :ok = UnitRegistry.register_player(caster, self())
    :ok = StatusStorage.apply_status(:player, 17, :sc_ensemblefatigue)
    assert Interpreter.can_use_skill?(:player, 17, 5068)
    refute Interpreter.can_use_skill?(:player, 17, 1)
    assert {:ok, ^caster} = CgSpecialsinger.cast(caster, :self, 1, CgSpecialsinger.definition())
    refute StatusStorage.has_status?(:player, 17, :sc_ensemblefatigue)
    assert Interpreter.can_use_skill?(:player, 17, 1)
  end

  test "casting without fatigue succeeds unchanged" do
    caster = PlayerStateFixture.build(%{character_id: 17, stats: %{combat_stats: %CombatStats{}}})
    :ok = UnitRegistry.register_player(caster, self())
    assert {:ok, ^caster} = CgSpecialsinger.cast(caster, :self, 1, CgSpecialsinger.definition())
  end
end
