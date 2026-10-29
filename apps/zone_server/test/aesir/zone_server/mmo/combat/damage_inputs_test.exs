defmodule Aesir.ZoneServer.Mmo.Combat.DamageInputsTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "a player's stat is its total: allocated plus job, equipment and status bonuses" do
    state =
      PlayerState.new(%Character{
        id: 7_001,
        account_id: 7_001,
        name: "Total",
        last_map: "prontera",
        class: 0,
        sex: "M",
        vit: 20
      })

    state =
      put_in(state.stats.modifiers, %{
        state.stats.modifiers
        | job_bonuses: %{vit: 3},
          equipment: %{vit: 5},
          status_effects: %{vit: 7}
      })

    :ok = UnitRegistry.register_player(state, self())

    assert DamageInputs.effective_stat(PlayerState.to_combatant(state), :vit) == 35

    assert DamageInputs.effective_luk(PlayerState.to_combatant(state)) ==
             state.stats.base_stats.luk
  end

  test "a monster's stat is its calculated value" do
    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 0,
      spawn_area: %MobSpawn.SpawnArea{x: 0, y: 0}
    }

    definition =
      Aesir.TestMob.definition(stats: %{str: 1, agi: 1, vit: 42, int: 17, dex: 1, luk: 1})

    mob = MobState.new(7_002, definition, spawn, "prontera", 0, 0)

    assert DamageInputs.effective_stat(MobState.to_combatant(mob), :vit) == mob.calculated.vit
    assert DamageInputs.effective_stat(MobState.to_combatant(mob), :int) == mob.calculated.int
  end
end
