defmodule Aesir.ZoneServer.Mmo.Skills.Whitesmith.WeaponRefineMenuTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.Emotion
  alias Aesir.Net.ProductionResult
  alias Aesir.Net.SkillMenuReply
  alias Aesir.Net.SpecialEffect
  alias Aesir.TestMob
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Whitesmith.WsWeaponrefine
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Mimic.copy(RefineOps)

    account =
      Repo.insert!(%Account{userid: "refine-menu", user_pass: "unused", email: "menu@test.local"})

    char =
      Repo.insert!(%Character{
        account_id: account.id,
        name: "MenuSmith",
        char_num: 0,
        class: 10,
        base_level: 99,
        job_level: 50,
        last_map: "prontera",
        last_x: 100,
        last_y: 100
      })

    item =
      Repo.insert!(%InventoryItem{
        char_id: char.id,
        nameid: 1_101,
        amount: 1,
        identify: 1,
        refine: 3
      })

    ore = Repo.insert!(%InventoryItem{char_id: char.id, nameid: 1_010, amount: 2})
    caster = PlayerState.new(char)

    stats = %{
      caster.stats
      | progression: %{caster.stats.progression | learned_skills: %{477 => 10}},
        current_state: %{caster.stats.current_state | sp: 100}
    }

    caster = %{caster | stats: stats, inventory: %{0 => item, 1 => ore}}
    :ok = UnitRegistry.register_player(caster, self())
    SpatialIndex.add_player(char.id, 100, 100, "prontera")
    pid = self()
    stub(Broadcast, :to_player, fn _id, packet -> MessageRouter.send_to(pid, packet) end)

    stub(Broadcast, :to_in_range, fn _, _, _, _, packet, _ ->
      MessageRouter.send_to(pid, packet)
    end)

    %{caster: caster}
  end

  test "opening_uses_learned_rank_and_mode_sp", %{caster: caster} do
    {:ok, definition} = Catalog.by_id(477)
    {:ok, prepared} = Player.cost(caster, WsWeaponrefine, :self, definition, 1)
    {paid, _} = Player.commit_primary(caster, prepared)
    assert {:ok, offered} = WsWeaponrefine.cast(paid, :self, 1, definition)
    sp = if GameMode.mode() == :renewal, do: 70, else: 95
    assert offered.stats.current_state.sp == sp

    assert %{
             level: 10,
             entry_ids: [0],
             preserve_pending_on_empty: true,
             context: %{learned_rank: 10, item_ids: %{0 => id}}
           } = offered.pending_menu_offer

    assert id == caster.inventory[0].id
    assert {:ok, empty} = WsWeaponrefine.cast(%{paid | inventory: %{}}, :self, 1, definition)
    assert empty.pending_menu_offer.entry_ids == []
    assert empty.stats.current_state.sp == sp
  end

  test "reply_uses_only_server_context", %{caster: caster} do
    test_pid = self()
    expected = caster.inventory[0].id

    expect(RefineOps, :weapon_skill, fn ^caster, 0, ^expected, 7 ->
      send(test_pid, :server_context_used)
      {caster, {:error, :no_ore}}
    end)

    context = %{trading?: false, menu: %{context: %{learned_rank: 7, item_ids: %{0 => expected}}}}

    assert {:error, :no_ore} =
             WsWeaponrefine.on_menu_reply(caster, %{id: 0, extras: [999, 0]}, 1, context)

    assert_received :server_context_used
    reject(&RefineOps.weapon_skill/4)

    assert {:error, :skill_failed} =
             WsWeaponrefine.on_menu_reply(caster, %{id: 0}, 10, %{context | trading?: true})

    assert {:error, :no_item} = WsWeaponrefine.on_menu_reply(caster, %{id: 99}, 10, context)
  end

  test "committed_outcome_drains_existing_feedback", %{caster: caster} do
    for {rate, success?, effect} <- [{10_000, true, 154}, {0, false, 155}] do
      stub(RefineDatabase, :level_info, fn :weapon, 1, 4 ->
        %{chances: %{normal: %{rate: rate, material_nameid: 1_010}}}
      end)

      item =
        Repo.insert!(%InventoryItem{
          char_id: caster.character_id,
          nameid: 1_101,
          amount: 1,
          identify: 1,
          refine: 3
        })

      ore = Repo.insert!(%InventoryItem{char_id: caster.character_id, nameid: 1_010, amount: 2})
      state = menu_state(%{caster | inventory: %{0 => item, 1 => ore}})
      reply = %SkillMenuReply{src_skill_id: 477, selected_id: 0, extra_ids: [999]}
      assert {:noreply, made} = SkillMenuHandler.handle_reply(reply, state)
      assert made.pending_skill_menu == nil
      assert made.game_state.stats.current_state.sp == 100
      assert made.game_state.pending_inventory_notify == []
      assert made.game_state.pending_production_result == nil

      assert_received {:send, :world,
                       {:production_result, %ProductionResult{success: ^success?, item_id: 1_101}}}

      assert_received {:send, :world, {:special_effect, %SpecialEffect{effect_id: ^effect}}}
      if not success?, do: assert_received({:send, :world, {:emotion, %Emotion{type: 23}}})
      assert {:noreply, ^made} = SkillMenuHandler.handle_reply(reply, made)
    end
  end

  test "non_player_refine_cast_is_noop" do
    {:ok, definition} = Catalog.by_id(477)

    spawn = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 1, y: 1}
    }

    mob = MobState.new(201, TestMob.definition(), spawn, "prontera", 1, 1)
    assert {:ok, ^mob} = WsWeaponrefine.cast(mob, :self, 10, definition)
  end

  defp menu_state(caster) do
    %{
      connection_pid: self(),
      game_state: caster,
      pending_skill_menu: %{
        skill_id: 477,
        kind: :INVENTORY_SLOTS,
        entry_ids: [0],
        level: 10,
        context: %{learned_rank: 10, item_ids: %{0 => caster.inventory[0].id}}
      }
    }
  end
end
