defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPotionpitcherTest do
  use ExUnit.Case, async: false
  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPotionpitcher
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Other suites redefine the shared compiled item scripts with fixtures; the
  # throw reads the real potion scripts.
  setup_all do
    ScriptCompiler.compile_all!()
  end

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    {:ok, definition} = Catalog.by_id(231)
    {:ok, definition: definition}
  end

  defp caster(item_id, opts \\ []) do
    state = player(10, opts)

    %{
      state
      | inventory: %{0 => %InventoryItem{nameid: item_id, amount: 2, equip: 0}},
        pending_inventory_persist: []
    }
  end

  defp target(opts) do
    state = player(Keyword.fetch!(opts, :id), opts)
    hp = Keyword.get(opts, :hp, 100)
    state = put_in(state.stats.current_state.hp, hp)
    %{state | action_state: Keyword.get(opts, :action_state, :idle)}
  end

  defp player(id, opts) do
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
    state = put_in(state.stats.base_stats.int, Keyword.get(opts, :int, 1))
    state = put_in(state.stats.modifiers.equipment, Keyword.get(opts, :equipment, %{}))

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

  defp mob_caster do
    mob_data = %MobDefinition{
      id: 1176,
      aegis_name: "VITATA",
      name: "Vitata",
      level: 20,
      hp: 1000,
      stats: %{str: 1, agi: 1, vit: 10, int: 1, dex: 1, luk: 1},
      matk: 0,
      attack_range: 1,
      size: :small,
      race: :insect,
      element: {:earth, 1},
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300
    }

    spawn_ref = %MobSpawn{
      mob: 1176,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(9_001, mob_data, spawn_ref, "prontera", 100, 100)
  end

  defp homunculus(owner_id, gid, opts \\ []) do
    %HomunculusState{
      id: gid + 1,
      owner_character_id: owner_id,
      class_id: 6_001,
      name: "Hildr",
      lifecycle: :active,
      action_state: Keyword.get(opts, :action_state, :idle),
      hp: Keyword.get(opts, :hp, 100),
      max_hp: 100,
      world_gid: gid,
      map_name: "test",
      x: 10,
      y: 10
    }
  end

  test "each level throws its own potion, read from the potion's script", %{
    definition: definition
  } do
    for {level, item_id} <- [{1, 501}, {2, 502}, {3, 503}, {4, 504}, {5, 505}] do
      state = caster(item_id, learned: %{231 => 5})

      assert {:deferred, updated, {:potion_delivery, {:player, 10}, {:potion, hp, sp}}} =
               AmPotionpitcher.cast(state, :self, level, definition)

      assert ItemContainer.held_amount(updated.inventory, item_id) == 1
      assert length(updated.pending_inventory_persist) == 1

      assert {hp > 0, sp > 0} == if(item_id == 505, do: {false, true}, else: {true, false})
    end
  end

  test "the rolled Red Potion takes the learned Pitcher level, not the cast level, and the thrower's terms",
       %{definition: definition} do
    roll = seeded_roll({1, 2, 3}, 45, 65)
    state = caster(501, learned: %{231 => 5, 227 => 2, 4 => 3}, vit: 15)

    # (roll * 160 / 100) then VIT 15 (+30%) then Increase HP Recovery 3 (+30%)
    hp =
      roll |> Kernel.*(160) |> div(100) |> Kernel.*(130) |> div(100) |> Kernel.*(130) |> div(100)

    assert {:deferred, _updated, {:potion_delivery, {:player, 10}, {:potion, ^hp, 0}}} =
             AmPotionpitcher.cast(state, :self, 1, definition)
  end

  test "a party member's recovery skill counts, its Increase Heal Rate does not", %{
    definition: definition
  } do
    member = target(id: 20, party_id: 7, vit: 1, learned: %{4 => 10})
    stub(UnitRegistry, :get_unit, fn :player, 20 -> {:ok, {PlayerState, member, self()}} end)
    :ok = StatusStorage.apply_status(:player, 20, :sc_inchealrate, val1: 50)
    roll = seeded_roll({7, 8, 9}, 45, 65)

    hp =
      roll |> Kernel.*(110) |> div(100) |> Kernel.*(102) |> div(100) |> Kernel.*(200) |> div(100)

    assert {:deferred, _updated, {:potion_delivery, {:player, 20}, {:potion, ^hp, 0}}} =
             AmPotionpitcher.cast(
               caster(501, party_id: 7, learned: %{231 => 1}),
               {:unit, 20},
               1,
               definition
             )
  end

  test "reading a potion's script heals no one" do
    state = caster(501)

    assert {:ok, %{hp: hp, sp: 0, per_hp: 0, per_sp: 0}} = AmPotionpitcher.read_potion(state, 501)
    assert hp in 45..65
    assert {:ok, %{hp: 0, sp: sp}} = AmPotionpitcher.read_potion(state, 505)
    assert sp in 40..60
  end

  test "a monster throws its level's table amount on itself, without a potion", %{
    definition: definition
  } do
    mob = mob_caster()
    roll = seeded_roll({3, 2, 1}, 0, 40)
    hp = div(div((105 + roll) * 170, 100) * 120, 100)

    expect(Combat, :apply_heal, fn :mob, 9_001, ^hp, 9_001 -> :ok end)

    assert :ok = AmPotionpitcher.validate(mob, :self, 2, definition)
    assert {:ok, ^mob} = AmPotionpitcher.cast(mob, :self, 2, definition)
  end

  test "a monster's throw at the Emperium heals nothing", %{definition: definition} do
    mob = mob_caster()
    emperium = %{mob_caster() | instance_id: 9_002, mob_data: %{mob.mob_data | id: 1_288}}

    stub(UnitRegistry, :get_unit, fn :mob, 9_002 -> {:ok, {MobState, emperium, self()}} end)
    reject(&Combat.apply_heal/4)

    assert {:ok, ^mob} = AmPotionpitcher.cast(mob, {:unit, {:mob, 9_002}}, 2, definition)
  end

  test "validate accepts self", %{definition: definition} do
    assert :ok = AmPotionpitcher.validate(caster(501), :self, 1, definition)
    assert :ok = AmPotionpitcher.validate(caster(501), {:unit, 10}, 1, definition)
  end

  test "validate accepts a live party member", %{definition: definition} do
    member = target(id: 20, party_id: 7)
    stub(UnitRegistry, :get_unit, fn :player, 20 -> {:ok, {PlayerState, member, self()}} end)

    assert :ok = AmPotionpitcher.validate(caster(501, party_id: 7), {:unit, 20}, 1, definition)
  end

  test "validate accepts a live guild member", %{definition: definition} do
    member = target(id: 20, guild_id: 7)
    stub(UnitRegistry, :get_unit, fn :player, 20 -> {:ok, {PlayerState, member, self()}} end)

    assert :ok = AmPotionpitcher.validate(caster(501, guild_id: 7), {:unit, 20}, 1, definition)
  end

  test "validate accepts only the exact owner's live Homunculus", %{definition: definition} do
    owned = homunculus(10, 30)
    foreign = homunculus(11, 31)

    stub(UnitRegistry, :get_unit, fn
      :homunculus, 30 -> {:ok, {HomunculusState, owned, self()}}
      :homunculus, 31 -> {:ok, {HomunculusState, foreign, self()}}
    end)

    assert :ok =
             AmPotionpitcher.validate(caster(501), {:unit, {:homunculus, 30}}, 1, definition)

    assert {:error, :target_restricted} =
             AmPotionpitcher.skilluse_check(
               caster(501),
               {:unit, {:homunculus, 31}},
               1,
               definition
             )
  end

  test "stranger is rejected without consumption", %{definition: definition} do
    stranger = target(id: 20)
    stub(UnitRegistry, :get_unit, fn :player, 20 -> {:ok, {PlayerState, stranger, self()}} end)
    state = caster(501, party_id: 7)

    assert {:error, :invalid_target} = AmPotionpitcher.cast(state, {:unit, 20}, 1, definition)
    assert ItemContainer.held_amount(state.inventory, 501) == 2
  end

  test "a dead ally passes the cast end and the throw ends without effect", %{
    definition: definition
  } do
    dead = target(id: 20, party_id: 7, action_state: :dead, hp: 0)
    stub(UnitRegistry, :get_unit, fn :player, 20 -> {:ok, {PlayerState, dead, self()}} end)
    state = caster(501, party_id: 7)

    assert :ok = AmPotionpitcher.validate(state, {:unit, 20}, 1, definition)

    assert {:skipped, ^state, :target_dead} =
             AmPotionpitcher.cast(state, {:unit, 20}, 1, definition)

    assert ItemContainer.held_amount(state.inventory, 501) == 2
  end

  test "missing selected potion returns an error without staging another potion", %{
    definition: definition
  } do
    state = caster(501)

    assert {:error, :missing_potion} = AmPotionpitcher.cast(state, :self, 2, definition)
    assert ItemContainer.held_amount(state.inventory, 501) == 2
    assert state.pending_inventory_persist == []
  end
end
