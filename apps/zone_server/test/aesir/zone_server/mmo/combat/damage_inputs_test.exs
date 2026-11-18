defmodule Aesir.ZoneServer.Mmo.Combat.DamageInputsTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.Factory

  alias Aesir.TestMob
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "a player's stat is its total: allocated plus job, equipment and status bonuses" do
    state =
      PlayerState.new(
        Aesir.Factory.build(:character,
          id: 7_001,
          account_id: 7_001,
          name: "Total",
          last_map: "prontera",
          class: 0,
          sex: "M",
          vit: 20
        )
      )

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
    definition = TestMob.definition(stats: %{str: 1, agi: 1, vit: 42, int: 17, dex: 1, luk: 1})

    mob =
      build(:mob_state,
        instance_id: 7_002,
        mob_data: definition,
        map_name: "prontera",
        x: 0,
        y: 0
      )

    assert DamageInputs.effective_stat(MobState.to_combatant(mob), :vit) == mob.calculated.vit
    assert DamageInputs.effective_stat(MobState.to_combatant(mob), :int) == mob.calculated.int
  end
end
