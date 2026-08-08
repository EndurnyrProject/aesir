defmodule Aesir.ZoneServer.Unit.Mob.StealOpsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
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

    assert {:error, :immune} = StealOps.attempt_mug(mob_state([:boss]), caster, 10)
    assert {:error, :immune} = StealOps.attempt_mug(mob_state([:status_immune]), caster, 10)
  end
end
