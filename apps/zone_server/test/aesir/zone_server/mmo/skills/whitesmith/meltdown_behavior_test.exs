defmodule Aesir.ZoneServer.Mmo.Skills.Whitesmith.MeltdownBehaviorTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.TestMob
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player
  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Whitesmith.WsMeltdown
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    stub(Resistance, :roll_success, fn _ -> true end)
    stub(Resistance, :roll_rate, fn _ -> true end)

    caster =
      PlayerStateFixture.build(%{
        character_id: 101,
        account_id: 101,
        inventory: %{},
        stats: %{combat_stats: %CombatStats{}, base_stats: %{dex: 0, int: 0}}
      })

    :ok = UnitRegistry.register_player(caster, self())
    %{caster: caster}
  end

  test "meltdown_cast_preserves_mode_timing_cost_and_held_rates", %{caster: caster} do
    {:ok, definition} = Catalog.by_id(384)

    timings =
      if GameMode.mode() == :renewal,
        do: [5, 5, 6, 6, 7, 7, 8, 8, 9, 10],
        else: [500, 500, 600, 600, 700, 700, 800, 800, 900, 1_000]

    for {expected, level} <- Enum.with_index(timings, 1) do
      inputs = Player.cast_stats(caster, 384)
      assert CastTime.compute(definition, level, inputs).total == expected
      assert {:ok, prepared} = Player.cost(caster, WsMeltdown, :self, definition, level)
      {paid, _} = Player.commit_primary(caster, prepared)

      assert paid.stats.current_state.sp ==
               100 - Enum.at([50, 50, 60, 60, 70, 70, 80, 80, 90, 90], level - 1)

      before_ms = System.monotonic_time(:millisecond)
      assert {:ok, ^paid} = WsMeltdown.cast(paid, :self, level, definition)
      after_ms = System.monotonic_time(:millisecond)
      held = StatusStorage.get_status(:player, 101, :sc_meltdown)
      assert held.val1 == level
      assert held.val2 == 100 * level
      assert held.val3 == 70 * level
      assert held.expires_at >= before_ms + 10_000 + 5_000 * level
      assert held.expires_at <= after_ms + 10_000 + 5_000 * level
    end
  end

  test "mob_meltdown_uses_raw_typed_recipient" do
    {:ok, definition} = Catalog.by_id(384)

    spawn = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 10, y: 10}
    }

    mob = MobState.new(201, TestMob.definition(), spawn, "prontera", 10, 10)
    :ok = UnitRegistry.register_unit(:mob, 201, MobState, mob, self())
    assert :ok = WsMeltdown.mob_cast(mob, {:unit, :player, 101}, 10, definition, %{})

    assert %{val1: 10, val2: 1_000, val3: 700, source_type: :mob, source_id: 201} =
             StatusStorage.get_status(:player, 101, :sc_meltdown)

    assert :ok = WsMeltdown.mob_cast(mob, {:unit, :mob, 201}, 1, definition, %{})

    assert %{source_type: :mob, source_id: 201} =
             StatusStorage.get_status(:mob, 201, :sc_meltdown)
  end
end
