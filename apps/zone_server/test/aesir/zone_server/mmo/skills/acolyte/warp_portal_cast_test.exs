defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.WarpPortalCastTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.SkillMenuReply
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit, as: SkillUnit
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlWarp
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :setup_ets_tables
  setup :set_mimic_private

  defp player do
    %PlayerState{
      character_id: 1000,
      map_name: "prontera",
      x: 10,
      y: 10,
      save_map: "izlude",
      save_x: 40,
      save_y: 50,
      action_state: :idle,
      movement_state: :standing,
      skill_cooldowns: %{},
      act_delay_until: 0,
      stats: %Stats{
        base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        current_state: %CurrentState{sp: 100, hp: 100},
        derived_stats: %DerivedStats{max_sp: 200, max_hp: 100},
        progression: %PlayerProgression{job_id: 4, learned_skills: %{27 => 4}},
        equipment: %Equipment{}
      }
    }
  end

  test "the cast spends SP without a gemstone; selection spends the stone before a failed placement" do
    map = MapData.new("prontera", 200, 200)
    stub(MapCache, :get, fn _ -> {:ok, map} end)

    assert {:ok, offered} = Interpreter.complete_cast(player(), 27, 1, {:ground, 11, 11})
    assert offered.stats.current_state.sp == 65
    assert offered.pending_menu_offer.labels == ["izlude"]
    assert offered.pending_inventory_persist == []

    reply_caster = %{offered | inventory: %{0 => %InventoryItem{nameid: 717, amount: 1}}}
    context = %{menu: offered.pending_menu_offer, homunculus: nil}
    test_pid = self()

    stub(SkillUnit, :place, fn caster, :al_warp, level, cell, opts ->
      send(test_pid, {:placement, level, cell, opts, caster.inventory})
      {:error, :no_walkable_cells}
    end)

    assert {:silent, paid} =
             AlWarp.on_menu_reply(reply_caster, %{id: 0, extras: []}, 1, context)

    assert paid.stats.current_state.sp == 65
    assert paid.inventory == %{}
    assert_received {:placement, 4, {11, 11}, [state: %{dest: {"izlude", 40, 50}}], %{}}
  end

  test "a destination removed while the menu is open closes silently" do
    stub(MapCache, :get, fn _ -> {:ok, MapData.new("prontera", 200, 200)} end)
    {:ok, offered, :no_consume} = AlWarp.cast(player(), {:ground, 11, 11}, 1, AlWarp.definition())
    changed = %{offered | save_map: "morocc", pending_menu_offer: nil}

    state = %SessionState{
      game_state: changed,
      connection_pid: self(),
      pending_skill_menu: offered.pending_menu_offer
    }

    reject(&Broadcast.to_player/2)

    assert {:noreply, closed} =
             SkillMenuHandler.handle_reply(
               %SkillMenuReply{src_skill_id: 27, selected_id: 0},
               state
             )

    assert closed.pending_skill_menu == nil
  end

  test "a stale skill reply releases work restrictions without clearing the portal menu" do
    {:ok, offered, :no_consume} = AlWarp.cast(player(), {:ground, 11, 11}, 1, AlWarp.definition())

    state = %SessionState{
      game_state: offered,
      connection_pid: self(),
      pending_skill_menu: offered.pending_menu_offer
    }

    assert SessionState.menu_work_in_progress?(state)
    refute SessionState.interaction_blocked?(state)

    assert {:noreply, unlocked} =
             SkillMenuHandler.handle_reply(
               %SkillMenuReply{src_skill_id: 279, selected_id: 0},
               state
             )

    assert unlocked.pending_skill_menu.skill_id == 27
    refute SessionState.menu_work_in_progress?(unlocked)
    refute SessionState.interaction_blocked?(unlocked)
  end

  test "losing the skill preserves the menu descriptor but releases its work lock" do
    stub(MapCache, :get, fn _ -> {:ok, MapData.new("prontera", 200, 200)} end)
    {:ok, offered, :no_consume} = AlWarp.cast(player(), {:ground, 11, 11}, 1, AlWarp.definition())
    unlearned = put_in(offered.stats.progression.learned_skills, %{})

    state = %SessionState{
      game_state: unlearned,
      connection_pid: self(),
      pending_skill_menu: offered.pending_menu_offer
    }

    reject(&Broadcast.to_player/2)

    assert {:noreply, kept} =
             SkillMenuHandler.handle_reply(
               %SkillMenuReply{src_skill_id: 27, selected_id: 0},
               state
             )

    assert kept.pending_skill_menu.skill_id == 27
    assert kept.pending_skill_menu.work_in_progress? == false
  end

  test "a normal attempt refuses exactly 90 percent weight while a waived item cast bypasses it" do
    stub(MapCache, :get, fn _ -> {:ok, MapData.new("prontera", 200, 200)} end)
    stub(JobManagement, :get_job_by_id, fn 4 -> {:ok, %{max_weight: 1000}} end)

    stub(ItemManagement, :get_item_by_id, fn 501 ->
      {:ok, %ItemDefinition{id: 501, aegis_name: "Red_Potion", name: "Red Potion", weight: 1}}
    end)

    heavy = %{player() | inventory: %{0 => %InventoryItem{nameid: 501, amount: 1170}}}
    assert {:error, :overweight} = Interpreter.preflight_cast(heavy, 27, 1, {:ground, 11, 11})
    lighter = put_in(heavy.inventory[0].amount, 1169)
    assert :ok = Interpreter.preflight_cast(lighter, 27, 1, {:ground, 11, 11})
    assert {:ok, _offered} = Interpreter.complete_item_cast(heavy, 27, 1, {:ground, 11, 11})
  end

  test "an item-granted portal keeps its level and waives the gemstone unless requirements were retained" do
    stub(MapCache, :get, fn _ -> {:ok, MapData.new("prontera", 200, 200)} end)
    caster = put_in(player().stats.progression.learned_skills, %{})
    assert {:ok, offered} = Interpreter.complete_item_cast(caster, 27, 2, {:ground, 11, 11})
    assert offered.stats.current_state.sp == 100
    assert offered.pending_menu_offer.context.consume_items? == false

    stub(SkillUnit, :place, fn _caster, :al_warp, 2, {11, 11}, _opts -> {:ok, %{}} end)

    assert {:ok, selected} =
             AlWarp.on_menu_reply(offered, %{id: 0, extras: []}, 2, %{
               menu: offered.pending_menu_offer
             })

    assert selected.inventory == %{}
    assert selected.stats.current_state.sp == 100
  end
end
