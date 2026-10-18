defmodule Aesir.ZoneServer.Unit.Mob.LootingTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemDrop.DropCalculator
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.Looting
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.LootHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Mimic.copy(Executor)
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", MapData.new("prontera", 200, 200)})
    :ok
  end

  test "a completed mob cast holds loot searches through the minimum action delay" do
    row = %{skill_id: 10, level: 1, delay: 0, cast_time: 100}
    state = %{looter() | casting: %{row: row}, ai_awake: false}
    stub(Executor, :execute, fn caster, ^row, :cast_end -> {:ok, caster} end)
    before = System.system_time(:millisecond)

    {:noreply, result} = CastingHandler.handle_cast_complete(state)

    after_time = System.system_time(:millisecond)
    assert result.act_delay_until >= before + 100
    assert result.act_delay_until <= after_time + 100
  end

  test "search chooses the oldest reachable item, keeps it, and walks in the loot state" do
    oldest = GroundItem.new(501, 1, 104, 100)
    nearby = GroundItem.new(502, 1, 101, 100)
    GroundItemStore.put("prontera", oldest)
    GroundItemStore.put("prontera", nearby)
    now = System.system_time(:millisecond)

    moving = AIStateMachine.process_ai(looter(), now)

    assert moving.loot_target_id == oldest.id
    assert moving.skill_state == :loot
    assert moving.movement_state == :moving
    assert List.last(moving.walk_path) == {104, 100}
    assert AIStateMachine.process_ai(moving, now).loot_target_id == oldest.id
  end

  test "retained loot drops north first even when normal drops are disabled" do
    items = for id <- 501..503, do: GroundItem.new(id, 2, 10, 10, false)
    state = %{looter() | looted_items: items, no_drops: true}
    parent = self()

    stub(Coordinator, :drop_items, fn map, drops, x, y, opts ->
      send(parent, {:drops, map, drops, x, y, opts})
      :ok
    end)

    Looting.drop_on_death(state)

    assert_received {:drops, "prontera",
                     [
                       {501, 2, 100, 101, false},
                       {502, 2, 101, 99, false},
                       {503, 2, 99, 100, false}
                     ], 100, 100, [ownership: _]}
  end

  test "the reward owner places normal drops before retained loot in one map delivery" do
    Mimic.copy(DropCalculator)
    stub(DropCalculator, :roll, fn _, _, _, _, _, _, _, _ -> [{502, 1, 100, 100, true}] end)
    parent = self()

    stub(Coordinator, :drop_items, fn "prontera", items, 100, 100 ->
      send(parent, {:items, items})
      :ok
    end)

    stats = Stats.from_character(%Character{})

    state = %SessionState{
      game_state: %PlayerState{character_id: 17, stats: stats},
      connection_pid: self()
    }

    payload = %{
      drops: [],
      mob_level: 1,
      map: "prontera",
      x: 100,
      y: 100,
      looted_items: [GroundItem.new(501, 3, 1, 1)]
    }

    LootHandler.mob_killed(payload, state)

    assert_received {:items, [{502, 1, 100, 100, true}, {501, 3, 100, 101, true}]}
  end

  test "losing an item shortens the loot walk to the next cell or the following cell" do
    for {left, remaining} <- [{750, 1}, {250, 2}] do
      step = {System.monotonic_time(:millisecond) + left, 1000, make_ref()}

      state = %{
        looter()
        | skill_state: :loot,
          movement_state: :moving,
          walk_path: [{101, 100}, {102, 100}, {103, 100}],
          pending_step: step,
          loot_target_id: 999_999
      }

      result = AIStateMachine.process_ai(state, System.system_time(:millisecond))

      assert result.skill_state == :idle
      assert length(result.walk_path) == remaining
      assert result.pending_step == step
      assert result.loot_target_id == nil
    end
  end

  test "a lost item discovered at a cell centre leaves just one further step" do
    item = GroundItem.new(501, 1, 104, 100)
    GroundItemStore.put("prontera", item)

    state = %{
      looter()
      | last_skillcheck: System.system_time(:millisecond),
        loot_target_id: item.id
    }

    moving = Looting.step(state, true, System.system_time(:millisecond))
    GroundItemStore.claim("prontera", item.id)

    {:noreply, shortened} = MovementHandler.handle_movement_tick(moving)

    assert shortened.walk_path == [{102, 100}]
    assert shortened.skill_state == :idle
    HitStop.cancel(shortened.pending_step)
  end

  test "a full bag replaces its oldest stack, and a lost claim grants nothing" do
    retained = for id <- 501..510, do: GroundItem.new(id, 1, 100, 100)
    incoming = GroundItem.new(511, 4, 100, 100)
    GroundItemStore.put("prontera", incoming)

    stub(Coordinator, :claim_loot_item, fn "prontera", id ->
      GroundItemStore.claim("prontera", id)
    end)

    result =
      AIStateMachine.process_ai(
        %{looter() | looted_items: retained},
        System.system_time(:millisecond)
      )

    assert Enum.map(result.looted_items, & &1.nameid) == Enum.to_list(502..511)
    assert List.last(result.looted_items).amount == 4
    stale = %{result | loot_target_id: incoming.id}

    assert Looting.step(stale, true, System.system_time(:millisecond)).looted_items ==
             result.looted_items
  end

  test "search refuses unreachable items, an action deadline and a mob without the looter mode" do
    state = looter()
    item = GroundItem.new(501, 1, 104, 100)
    GroundItemStore.put("prontera", item)
    now = System.system_time(:millisecond)
    assert Looting.search(%{state | act_delay_until: now}, true, now).loot_target_id == nil
    assert Looting.search(state, false, now).loot_target_id == nil
    non_looter = %{state | mob_data: %{state.mob_data | modes: [:can_move]}}
    assert Looting.search(non_looter, true, now).loot_target_id == nil
    assert Looting.search(state, true, now).loot_target_id == item.id
    Mimic.copy(LineOfSight)
    stub(LineOfSight, :passable?, fn _, _, _ -> false end)
    assert Looting.search(state, true, now).loot_target_id == item.id
    stub(LineOfSight, :clear?, fn _, _, _ -> false end)
    assert Looting.search(state, true, now).loot_target_id == nil
  end

  test "a looter takes a protected stack on its cell and keeps it for its death drop" do
    now = System.system_time(:millisecond)

    item =
      GroundItem.new(501, 3, 100, 100, true,
        owners: {10, nil, nil},
        unlock_at: {now + 1000, now + 2000, now + 3000}
      )

    GroundItemStore.put("prontera", item)

    stub(Coordinator, :claim_loot_item, fn "prontera", id ->
      GroundItemStore.claim("prontera", id)
    end)

    result = AIStateMachine.process_ai(looter(), now)

    assert {:error, :gone} = GroundItemStore.get("prontera", item.id)
    assert [%GroundItem{nameid: 501, amount: 3}] = result.looted_items
    assert result.loot_target_id == nil
    assert result.skill_state == :idle
  end

  defp looter do
    {:ok, data} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 5000, spawn_area: nil}

    MobState.new(
      919,
      %{data | modes: [:looter, :can_move, :can_attack]},
      spawn,
      "prontera",
      100,
      100
    )
  end
end
