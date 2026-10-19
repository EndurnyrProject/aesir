defmodule Aesir.ZoneServer.Unit.Mob.StealOpsTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  setup :setup_ets_tables

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.StealOps

  defp mob_state(modes \\ []) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "TEST_MOB",
      name: "Test Mob",
      level: 30,
      hp: 1_000,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 500,
      class: Aesir.ZoneServer.Mmo.MobManagement.MobMode.class(modes),
      modes: modes
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 0, y: 0}
    }

    MobState.new(1, mob_data, spawn_ref, "prontera", 0, 0)
  end

  defp stealable_mob(dex, drop_rate) do
    state = mob_state()

    mob_data = %{
      state.mob_data
      | stats: %{state.mob_data.stats | dex: dex},
        drops: [%MobDrop{item: "Red_Potion", rate: drop_rate}]
    }

    Aesir.TestMob.publish(%{state | mob_data: mob_data})
  end

  @tag game_mode: :pre_renewal
  test "classic compares a zero-based roll to the positive fractional threshold" do
    rng = fn 10_000 -> 0 end
    assert {:ok, 501, _state} = StealOps.attempt_steal(stealable_mob(1, 1), 1, 1, rng)
  end

  test "protected and unresolved drops consume no drop rolls" do
    base = stealable_mob(1, 1)

    state = %{
      base
      | mob_data: %{
          base.mob_data
          | drops: [
              %MobDrop{item: "Jellopy", rate: 10_000, steal_protected: true},
              %MobDrop{item: "NotARealItem_XYZ", rate: 10_000},
              %MobDrop{item: "Red_Potion", rate: 1}
            ]
        }
    }

    rng = fn bound ->
      send(self(), {:steal_roll, bound})
      0
    end

    assert {:ok, 501, _state} = StealOps.attempt_steal(state, 400, 10, rng)
    assert_received {:steal_roll, 10_000}
    refute_received {:steal_roll, 10_000}

    if GameMode.mode() == :renewal do
      assert_received {:steal_roll, 100}
    else
      refute_received {:steal_roll, 100}
    end
  end

  test "the caster's additive bonus can lift a refused base chance above zero" do
    state = stealable_mob(200, 10_000)
    assert {:error, :miss} = StealOps.attempt_steal(state, 1, 1)

    assert {:ok, 501, _state} =
             StealOps.attempt_steal(state, %{dex: 1, add_steal_rate: 100}, 1, fn _ -> 0 end)
  end

  test "masters and Treasure race-group monsters become terminally protected" do
    base = stealable_mob(1, 10_000)
    treasure = %{base | mob_data: %{base.mob_data | race_groups: [:treasure]}}

    for state <- [%{base | master_id: 42}, treasure] do
      assert {:error, :protected, locked} = StealOps.attempt_steal(state, 400, 10)
      assert locked.stolen_from
    end
  end

  test "NoMobLoot refuses and locks the monster even after the map flag is removed" do
    state = stealable_mob(1, 10_000)
    :ok = MapFlags.set_runtime(state.map_name, :nomobloot, true)
    assert {:error, :protected, locked} = StealOps.attempt_steal(state, 400, 10)
    assert locked.stolen_from
    :ok = MapFlags.set_runtime(state.map_name, :nomobloot, false)
    assert {:error, :already_stolen} = StealOps.attempt_steal(locked, 400, 10)
  end

  test "a body-state refusal is retryable after the status ends" do
    state = stealable_mob(1, 10_000)
    :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_stun, val1: 1)
    assert {:error, :status_blocked} = StealOps.attempt_steal(state, 400, 10)
    refute state.stolen_from
    StatusStorage.take_status(:mob, state.instance_id, :sc_stun)
    assert {:ok, 501, unlocked} = StealOps.attempt_steal(state, 400, 10)
    assert unlocked.stolen_from
  end

  test "status immunity makes the monster terminally unavailable to item stealing" do
    assert {:error, :immune, locked} =
             StealOps.attempt_steal(mob_state([:status_immune]), 100, 10)

    assert locked.stolen_from
    assert {:error, :already_stolen} = StealOps.attempt_steal(locked, 100, 10)
  end

  @tag game_mode: :pre_renewal
  test "classic steal scales each drop's rate by the steal chance instead of rolling the chance first" do
    # caster DEX 400 vs mob DEX 1 at level 10: chance (400 - 1) / 2 + 64 = 263 percent,
    # so a 50 percent drop is lifted past certainty; renewal would still roll the drop at 50 percent.
    for _ <- 1..30 do
      assert {:ok, 501, stolen} = StealOps.attempt_steal(stealable_mob(1, 5_000), 400, 10)
      assert stolen.stolen_from
    end
  end

  test "a steal chance below one percent fails without touching the drops in both modes" do
    assert {:error, :miss} = StealOps.attempt_steal(stealable_mob(200, 10_000), 1, 1)
  end

  test "uses the Renewal mug rate and zeny formulas, then marks coins as stolen" do
    state = mob_state()
    caster = %{dex: 500, luk: 500, base_level: 230}

    :rand.seed(:exsss, {3195, 3196, 3197})

    assert {:ok, 270, mugged} = StealOps.attempt_mug(state, caster, 10)
    assert mugged.coin_stolen
    assert {:error, :no_coin} = StealOps.attempt_mug(mugged, caster, 10)
  end

  test "rejects boss and status-immune mobs" do
    caster = %{dex: 500, luk: 500, base_level: 230}

    assert {:error, :immune} =
             StealOps.attempt_mug(
               mob_state([:detector, :status_immune, :knockback_immune]),
               caster,
               10
             )

    assert {:error, :immune} = StealOps.attempt_mug(mob_state([:status_immune]), caster, 10)
  end
end
