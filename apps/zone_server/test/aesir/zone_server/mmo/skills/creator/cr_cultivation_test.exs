defmodule Aesir.ZoneServer.Mmo.Skills.Creator.CrCultivationTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Creator.CrCultivation
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    previous = Application.get_env(:zone_server, :cultivation_rng)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:zone_server, :cultivation_rng, previous),
        else: Application.delete_env(:zone_server, :cultivation_rng)
    end)

    {:ok, definition} = Catalog.by_id(491)
    {:ok, definition: definition, caster: player(51_001)}
  end

  test "an occupied cell fails and keeps the seed", %{definition: definition, caster: caster} do
    reject(&Coordinator.summon_mob/5)

    for {type, id} <- [{:player, 51_002}, {:mob, 51_003}, {:homunculus, 51_004}] do
      :ok = SpatialIndex.add_unit(type, id, 101, 100, "prontera")

      assert {:failed, ^caster, :skill_failed, :spare_items} =
               CrCultivation.cast(caster, {:ground, 101, 100}, 1, definition)

      :ok = SpatialIndex.remove_unit(type, id)
    end
  end

  test "a failed roll shows itself and spends the seed", %{definition: definition, caster: caster} do
    rolls([50])
    reject(&Coordinator.summon_mob/5)

    assert {:failed, ^caster, :skill_failed, :after_effect} =
             CrCultivation.cast(caster, {:ground, 101, 100}, 1, definition)
  end

  test "level 1 grows a Black or a Red Mushroom for five minutes, with no owner", %{
    definition: definition,
    caster: caster
  } do
    for {draw, mob_id} <- [{1, 1_084}, {2, 1_085}] do
      rolls([51, draw])
      expect_spawn(mob_id)
      assert {:ok, ^caster} = CrCultivation.cast(caster, {:ground, 101, 100}, 1, definition)
    end
  end

  test "level 2 grows a plant from the weighted table", %{definition: definition, caster: caster} do
    # Draws are 1..100; the table reads them as 0..99.
    for {draw, mob_id} <- [
          {1, 1_080},
          {30, 1_080},
          {31, 1_078},
          {55, 1_078},
          {56, 1_081},
          {80, 1_081},
          {81, 1_082},
          {90, 1_082},
          {91, 1_079},
          {98, 1_079},
          {99, 1_083},
          {100, 1_083}
        ] do
      rolls([100, draw])
      expect_spawn(mob_id)
      assert {:ok, ^caster} = CrCultivation.cast(caster, {:ground, 101, 100}, 2, definition)
    end
  end

  test "a refused spawn still succeeds", %{definition: definition, caster: caster} do
    rolls([51, 1])

    stub(Coordinator, :summon_mob, fn _map, _mob, _x, _y, _opts -> {:error, :no_walkable_cell} end)

    assert {:ok, ^caster} = CrCultivation.cast(caster, {:ground, 101, 100}, 1, definition)
  end

  test "each level plants its own seed", %{definition: definition, caster: caster} do
    assert CrCultivation.dynamic_item_cost(caster, nil, 1, definition) == [%{id: 921, amount: 1}]
    assert CrCultivation.dynamic_item_cost(caster, nil, 2, definition) == [%{id: 905, amount: 1}]
  end

  defp rolls(draws) do
    {:ok, agent} = Agent.start_link(fn -> draws end)

    Application.put_env(:zone_server, :cultivation_rng, fn _upper ->
      Agent.get_and_update(agent, fn [draw | rest] -> {draw, rest} end)
    end)
  end

  defp expect_spawn(mob_id) do
    expect(Coordinator, :summon_mob, fn "prontera", ^mob_id, 101, 100, opts ->
      assert opts == [lifetime_ms: 300_000]
      {:ok, 1}
    end)
  end

  defp player(id) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Creator#{id}",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 4_019,
      sex: "M",
      base_level: 99
    })
  end
end
