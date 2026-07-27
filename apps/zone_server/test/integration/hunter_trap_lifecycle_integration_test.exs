defmodule Aesir.ZoneServer.Integration.HunterTrapLifecycleIntegrationTest do
  @moduledoc """
  Real-session coverage of the Hunter trap lifecycle now that the whole trap
  branch is published: catalyst accounting on cast, the PvE activation gate,
  activator-centered area traps, the linked Ankle Snare teardown in both
  directions, and the three natural-expiry policies (item drop, become used,
  Claymore spending its neighbours).

  Timing-sensitive assertions run against a supervised, manually ticked manager
  so no assertion depends on wall-clock expiry.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.Map.MapManager
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence

  @map "prontera"
  @hunter_class 11
  @trap_item 1065

  @skidtrap 115
  @landmine 116
  @anklesnare 117
  @sandman 119
  @flasher 120
  @freezingtrap 121
  @blastmine 122
  @claymoretrap 123

  setup do
    Mimic.copy(Resistance)
    stub(Resistance, :roll_success, fn _effective_rate -> true end)
    :ok
  end

  setup {Aesir.MimicMode, :global}

  setup do
    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    {:ok, manager: manager}
  end

  test "a paid trap cast spends its catalyst and a rejected cast leaves it untouched" do
    character = insert_hunter(learned_skills: skills(%{@sandman => 1, @flasher => 1}))
    assert {:ok, _item} = Persistence.insert_item(character.id, %{nameid: @trap_item, amount: 1})
    session = start_hunter(character, {150, 150})

    rejected = cast_ground(session, @flasher, 1, {151, 150})

    assert Inventory.held_amount(rejected.inventory, @trap_item) == 1
    assert rejected.stats.current_state.sp == 100
    assert [] == Enum.filter(Storage.all(), &(&1.skill_name == :ht_flasher))

    accepted = cast_ground(session, @sandman, 1, {151, 150})

    assert Inventory.held_amount(accepted.inventory, @trap_item) == 0
    assert accepted.stats.current_state.sp == 88

    assert %Group{center: {151, 150}, state: %{trap: %TrapState{phase: :armed}}} =
             find_group(:ht_sandman)
  end

  test "a player trap ignores a player mover and detonates on a mob" do
    caster = start_hunter(insert_hunter([]), {150, 160})
    bystander = start_hunter(insert_hunter([]), {151, 160})
    mob = spawn_test_mob(@map, {152, 160}, unit_id: 99_301, max_hp: 10_000, hp: 10_000)

    assert :ok = Manager.register(trap_group(20_001, :ht_landmine, @landmine, caster, {151, 160}))

    assert :ok = Manager.trigger(20_001, {:player, bystander.character.id}, :on_touch)

    assert %Group{visible?: false, state: %{trap: %TrapState{phase: :armed}}} =
             Storage.get(20_001)

    assert get_player_state(bystander.pid).stats.current_state.hp == 500

    assert :ok = Manager.trigger(20_001, {:mob, mob.unit_id}, :on_touch)

    assert %Group{visible?: true, state: %{trap: %TrapState{phase: :used}}} = Storage.get(20_001)
    assert eventually(fn -> get_mob_state(mob.pid).hp < 10_000 end)
  end

  test "Freezing Trap centres its splash on the activator instead of the trap cell" do
    caster = start_hunter(insert_hunter([]), {150, 170})
    activator = spawn_test_mob(@map, {158, 170}, unit_id: 99_311, max_hp: 100_000, hp: 100_000)
    neighbour = spawn_test_mob(@map, {159, 170}, unit_id: 99_312, max_hp: 100_000, hp: 100_000)
    distant = spawn_test_mob(@map, {161, 170}, unit_id: 99_313, max_hp: 100_000, hp: 100_000)

    on_exit(fn ->
      for id <- [activator.unit_id, neighbour.unit_id, distant.unit_id],
          do: StatusStorage.clear_unit_statuses(:mob, id)
    end)

    group = trap_group(20_002, :ht_freezingtrap, @freezingtrap, caster, {154, 170})
    assert :ok = Manager.register(group)

    assert :ok = Manager.trigger(20_002, {:mob, activator.unit_id}, :on_touch)

    assert %Group{state: %{trap: %TrapState{phase: :used}}} = Storage.get(20_002)
    assert StatusStorage.has_status?(:mob, activator.unit_id, :sc_freeze)
    assert StatusStorage.has_status?(:mob, neighbour.unit_id, :sc_freeze)
    refute StatusStorage.has_status?(:mob, distant.unit_id, :sc_freeze)
  end

  test "an Ankle Snare group and its capture status release each other", %{manager: manager} do
    caster = start_hunter(insert_hunter([]), {150, 180})
    first = spawn_test_mob(@map, {152, 180}, unit_id: 99_321, max_hp: 10_000, hp: 10_000)
    second = spawn_test_mob(@map, {154, 180}, unit_id: 99_322, max_hp: 10_000, hp: 10_000)

    on_exit(fn ->
      for id <- [first.unit_id, second.unit_id],
          do: StatusStorage.clear_unit_statuses(:mob, id)
    end)

    assert :ok =
             Manager.register(trap_group(20_003, :ht_anklesnare, @anklesnare, caster, {152, 180}))

    assert :ok =
             Manager.register(trap_group(20_004, :ht_anklesnare, @anklesnare, caster, {154, 180}))

    assert :ok = Manager.trigger(20_003, {:mob, first.unit_id}, :on_touch)
    assert :ok = Manager.trigger(20_004, {:mob, second.unit_id}, :on_touch)

    assert %Group{expires_at: expires_at, state: %{trap: %TrapState{phase: :captured}}} =
             Storage.get(20_003)

    assert %Group{state: %{trap: %TrapState{phase: :captured}}} = Storage.get(20_004)
    assert StatusStorage.has_status?(:mob, first.unit_id, :sc_anklesnare)
    assert StatusStorage.has_status?(:mob, second.unit_id, :sc_anklesnare)

    assert :ok = Manager.tick(manager, expires_at)

    assert nil == Storage.get(20_003)
    refute StatusStorage.has_status?(:mob, first.unit_id, :sc_anklesnare)

    assert :ok = StatusInterpreter.remove_status(:mob, second.unit_id, :sc_anklesnare)

    assert eventually(fn -> Storage.get(20_004) == nil end)
    refute StatusStorage.has_status?(:mob, second.unit_id, :sc_anklesnare)
  end

  test "a paid trap returns exactly one floor item on natural expiry", %{manager: manager} do
    character = insert_hunter(learned_skills: skills(%{@skidtrap => 1}))
    assert {:ok, _item} = Persistence.insert_item(character.id, %{nameid: @trap_item, amount: 1})
    session = start_hunter(character, {150, 150})

    state = cast_ground(session, @skidtrap, 1, {151, 150})
    assert Inventory.held_amount(state.inventory, @trap_item) == 0

    assert %Group{
             group_id: group_id,
             expires_at: expires_at,
             state: %{trap: %TrapState{return_item_on_expiry?: true}}
           } = find_group(:ht_skidtrap)

    # The return item is dropped through the map's coordinator, which boots
    # lazily after the application starts.
    assert eventually(fn -> match?({:ok, _pid}, MapManager.get_coordinator(@map)) end)

    assert :ok = Manager.tick(manager, expires_at)

    assert nil == Storage.get(group_id)

    # The manager hands the returned catalyst to the map coordinator asynchronously.
    assert eventually(fn -> GroundItemStore.query_in_range(@map, 151, 150, 0) != [] end)

    assert [%GroundItem{nameid: @trap_item, amount: 1, x: 151, y: 150}] =
             GroundItemStore.query_in_range(@map, 151, 150, 0)
  end

  test "Blast Mine and Claymore Trap become used on natural expiry", %{manager: manager} do
    caster = start_hunter(insert_hunter([]), {160, 160})

    blast = paid_trap_group(20_005, :ht_blastmine, @blastmine, caster, {161, 160})
    claymore = paid_trap_group(20_006, :ht_claymoretrap, @claymoretrap, caster, {163, 160})

    assert :ok = Manager.register(blast)
    assert :ok = Manager.register(claymore)
    assert :ok = Manager.tick(manager, blast.expires_at)

    for group_id <- [20_005, 20_006] do
      assert %Group{visible?: true, state: %{trap: %TrapState{phase: :used}}} =
               Storage.get(group_id)
    end

    assert [] == GroundItemStore.query_in_range(@map, 161, 160, 3)
  end

  test "Claymore Trap spends nearby armed eligible traps without firing their effects" do
    caster = start_hunter(insert_hunter([]), {150, 190})
    activator = spawn_test_mob(@map, {160, 190}, unit_id: 99_331, max_hp: 100_000, hp: 100_000)
    neighbour = spawn_test_mob(@map, {162, 190}, unit_id: 99_332, max_hp: 100_000, hp: 100_000)

    on_exit(fn ->
      for id <- [activator.unit_id, neighbour.unit_id],
          do: StatusStorage.clear_unit_statuses(:mob, id)
    end)

    assert :ok =
             Manager.register(
               trap_group(20_007, :ht_claymoretrap, @claymoretrap, caster, {160, 190})
             )

    assert :ok = Manager.register(trap_group(20_008, :ht_sandman, @sandman, caster, {162, 190}))
    assert :ok = Manager.register(trap_group(20_009, :ht_skidtrap, @skidtrap, caster, {161, 190}))
    assert :ok = Manager.register(trap_group(20_010, :ht_sandman, @sandman, caster, {166, 190}))

    assert :ok = Manager.trigger(20_007, {:mob, activator.unit_id}, :on_touch)

    assert %Group{state: %{trap: %TrapState{phase: :used}}} = Storage.get(20_007)
    assert %Group{state: %{trap: %TrapState{phase: :used}}} = Storage.get(20_008)
    assert %Group{state: %{trap: %TrapState{phase: :armed}}} = Storage.get(20_009)
    assert %Group{state: %{trap: %TrapState{phase: :armed}}} = Storage.get(20_010)

    refute StatusStorage.has_status?(:mob, neighbour.unit_id, :sc_sleep)
    refute StatusStorage.has_status?(:mob, activator.unit_id, :sc_sleep)
  end

  defp start_hunter(character, position) do
    session = start_player_session(character: character, map_name: @map, position: position)
    on_exit(fn -> end_player_session(session) end)
    flush_packets()
    session
  end

  defp cast_ground(session, skill_id, level, {x, y}) do
    simulate_incoming_message(session.pid, %GroundSkillCast{
      skill_id: skill_id,
      level: level,
      x: x,
      y: y
    })

    get_player_state(session.pid)
  end

  defp find_group(skill_name) do
    assert eventually(fn -> Enum.any?(Storage.all(), &(&1.skill_name == skill_name)) end)
    Enum.find(Storage.all(), &(&1.skill_name == skill_name))
  end

  defp trap_group(group_id, skill_name, skill_id, caster, {x, y}, state \\ %{}) do
    now = System.monotonic_time(:millisecond)

    %Group{
      group_id: group_id,
      skill_id: skill_id,
      skill_name: skill_name,
      level: 5,
      caster_id: caster.character.id,
      caster_type: :player,
      map_name: @map,
      center: {x, y},
      cells: [{x, y}],
      next_tick_at: now + 60_000,
      expires_at: now + 60_000,
      interval: 1_000,
      visible?: false,
      state: Map.merge(%{base_damage: 500, trap: trap_state(skill_name)}, state)
    }
  end

  defp paid_trap_group(group_id, skill_name, skill_id, caster, cell) do
    now = System.monotonic_time(:millisecond)
    group = trap_group(group_id, skill_name, skill_id, caster, cell)

    %{
      group
      | visible?: true,
        expires_at: now + 100,
        state: %{
          group.state
          | trap: %{group.state.trap | return_item_on_expiry?: true}
        }
    }
  end

  defp trap_state(skill_name) do
    %TrapState{
      reclaim_item_id: @trap_item,
      claymore_spendable?: skill_name != :ht_skidtrap,
      natural_expiry: natural_expiry(skill_name)
    }
  end

  defp natural_expiry(skill_name) when skill_name in [:ht_blastmine, :ht_claymoretrap],
    do: :become_used

  defp natural_expiry(_skill_name), do: :drop_item

  defp skills(levels) do
    Map.new(levels, fn {id, level} -> {Integer.to_string(id), level} end)
  end

  defp insert_hunter(overrides) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "traplife#{uniq}",
        userid: "traplife#{uniq}",
        user_pass: "password",
        email: "traplife#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          char_num: 0,
          name: "TrapLife#{uniq}",
          class: @hunter_class,
          base_level: 50,
          job_level: 50,
          str: 10,
          agi: 10,
          vit: 10,
          int: 10,
          dex: 50,
          luk: 10,
          hp: 500,
          max_hp: 500,
          sp: 100,
          max_sp: 100,
          last_map: @map,
          last_x: 150,
          last_y: 150,
          save_map: @map,
          save_x: 150,
          save_y: 150
        },
        Map.new(overrides)
      )

    {:ok, character} =
      %Character{}
      |> Character.changeset(attrs)
      |> Repo.insert()

    character
  end
end
