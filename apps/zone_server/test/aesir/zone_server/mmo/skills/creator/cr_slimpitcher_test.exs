defmodule Aesir.ZoneServer.Mmo.Skills.Creator.CrSlimpitcherTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Creator.CrSlimpitcher
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Other suites redefine the shared compiled item scripts with fixtures; the
  # throw reads the real potion scripts.
  setup_all do
    ScriptCompiler.compile_all!()
  end

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    {:ok, definition} = Catalog.by_id(478)
    test_pid = self()

    stub(Combat, :apply_heal, fn type, id, amount, source ->
      send(test_pid, {:heal, {type, id}, amount, source})
      :ok
    end)

    {:ok, definition: definition}
  end

  test "each level band throws its own slim potion", %{definition: definition} do
    potions = for level <- 1..10, do: CrSlimpitcher.dynamic_item_cost(nil, nil, level, definition)

    assert Enum.map(potions, fn [%{id: id, amount: 1}] -> id end) ==
             [545, 545, 545, 545, 545, 546, 546, 546, 546, 547]
  end

  test "heals the caster, a party member and a guild guardian; skips strangers and the Emperium",
       %{definition: definition} do
    caster = place_player(player(10, party_id: 7, guild_id: 3, learned: %{478 => 1}), {100, 100})
    place_player(player(20, party_id: 7, vit: 10), {102, 100})
    place_player(player(30), {101, 101})
    place_mob(monster(900, 1002, guild_id: 3), {99, 100})
    place_mob(monster(901, 1288, guild_id: 3), {100, 99})

    roll = seeded_roll({4, 5, 6}, 45, 65)
    # The caster's rate: 100 + 10 * Slim Pitcher 1 = 110 percent.
    thrown = div(roll * 110, 100)

    assert {:ok, _caster} = CrSlimpitcher.cast(caster, {:ground, 100, 100}, 1, definition)

    caster_hp = div(thrown * 102, 100)
    member_hp = div(thrown * 120, 100)
    guardian_hp = div(thrown * 120, 100)

    assert_received {:heal, {:player, 10}, {:potion, ^caster_hp, 0}, 10}
    assert_received {:heal, {:player, 20}, {:potion, ^member_hp, 0}, 10}
    assert_received {:heal, {:mob, 900}, ^guardian_hp, 10}
    refute_received {:heal, {:player, 30}, _amount, _source}
    refute_received {:heal, {:mob, 901}, _amount, _source}
  end

  test "a throw that heals nobody still succeeds", %{definition: definition} do
    caster = place_player(player(10, party_id: 7), {100, 100})
    place_player(player(20, party_id: 7), {101, 100})

    for id <- [10, 20],
        do: :ok = StatusStorage.apply_status(:player, id, :sc_norecover_state)

    assert {:ok, ^caster} = CrSlimpitcher.cast(caster, {:ground, 100, 100}, 1, definition)
    refute_received {:heal, _ref, _amount, _source}
  end

  test "the caster's own homunculus is healed in the caster's session and the cell is announced" do
    stub(MapCache, :get, fn "prontera" -> {:ok, MapData.new("prontera", 200, 200)} end)
    caster = place_player(player(10, learned: %{478 => 1}), {100, 100})

    companion = %HomunculusState{
      id: 1,
      owner_character_id: 10,
      class_id: 6_001,
      name: "Lif",
      lifecycle: :active,
      hp: 50,
      max_hp: 900,
      vit: 30,
      int: 20,
      world_gid: 500,
      map_name: "prontera",
      x: 101,
      y: 100
    }

    :ok = UnitRegistry.register_unit(:homunculus, 500, HomunculusState, companion, self())
    :ok = SpatialIndex.add_unit(:homunculus, 500, 101, 100, "prontera")

    expect(Broadcast, :to_in_range, fn "prontera", 100, 100, _range, packet ->
      assert %Aesir.Net.GroundSkill{skill_id: 478, src_id: 10, level: 1, x: 100, y: 100} = packet
      :ok
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    caster = %{
      caster
      | inventory: %{0 => %InventoryItem{nameid: 545, amount: 2, equip: 0}},
        pending_inventory_persist: []
    }

    roll = seeded_roll({4, 5, 6}, 45, 65)
    homunculus_hp = roll |> Kernel.*(110) |> div(100) |> Kernel.*(160) |> div(100)

    assert {:local_effects, cast, effects} = Interpreter.cast(caster, 478, 1, {:ground, 100, 100})
    assert cast.inventory[0].amount == 1

    assert {:homunculus, {:apply_heal, 500, {:potion, homunculus_hp, 0}, {:player, 10}}} in effects
  end

  defp place_player(state, {x, y}) do
    state = %{state | x: x, y: y}
    :ok = UnitRegistry.register_player(state, self())
    :ok = SpatialIndex.add_player(state.character_id, x, y, "prontera")
    state
  end

  defp place_mob(state, {x, y}) do
    :ok = UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
    :ok = SpatialIndex.add_unit(:mob, state.instance_id, x, y, "prontera")
  end

  defp monster(instance_id, mob_id, opts) do
    spawn = %MobSpawn{
      mob: mob_id,
      amount: 1,
      respawn_time: 0,
      spawn_area: %MobSpawn.SpawnArea{x: 0, y: 0}
    }

    definition = Aesir.TestMob.definition(id: mob_id)
    state = MobState.new(instance_id, definition, spawn, "prontera", 0, 0)
    %{state | guild_id: Keyword.get(opts, :guild_id, 0)}
  end

  defp player(id, opts \\ []) do
    state =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Pitcher#{id}",
        class: 18,
        sex: "M",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 50,
        hp: 100,
        sp: 100
      })

    state = put_in(state.stats.progression.learned_skills, Keyword.get(opts, :learned, %{}))
    state = put_in(state.stats.base_stats.vit, Keyword.get(opts, :vit, 1))

    %{
      state
      | party_id: Keyword.get(opts, :party_id, 0),
        guild_id: Keyword.get(opts, :guild_id, 0)
    }
  end

  defp seeded_roll(seed, minimum, maximum) do
    :rand.seed(:exsss, seed)
    roll = minimum + :rand.uniform(maximum - minimum + 1) - 1
    :rand.seed(:exsss, seed)
    roll
  end
end
