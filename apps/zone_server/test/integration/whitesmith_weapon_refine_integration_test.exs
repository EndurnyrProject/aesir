defmodule Aesir.ZoneServer.Integration.WhitesmithWeaponRefineIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.Emotion
  alias Aesir.Net.EquipItem
  alias Aesir.Net.FameUpdate
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.ProductionResult
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillMenu
  alias Aesir.Net.SkillMenuReply
  alias Aesir.Net.SpecialEffect
  alias Aesir.Net.UnequipItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup do
    Mimic.copy(Persistence)
    :ok
  end

  test "real_refine_menu_commits_once" do
    {session, weapon, ore} = start_smith()
    force_roll(session, 0)
    initial = get_player_state(session.pid)
    pending = open(session)
    assert pending.level == 10
    assert pending.context.item_ids[0] == weapon.id
    cost = if GameMode.mode() == :renewal, do: 30, else: 5

    assert get_player_state(session.pid).stats.current_state.sp ==
             initial.stats.current_state.sp - cost

    clear_packet_inbox()
    reply(session)
    assert_receive {:packet_sent, %ProductionResult{success: true, item_id: 1_101}, _}, 1_000
    assert_receive {:packet_sent, %ItemRemoved{index: 3, amount: 1}, _}, 1_000
    assert_receive {:packet_sent, %ItemAdded{index: 2, refine: 10}, _}, 1_000
    assert_receive {:packet_sent, %SpecialEffect{effect_id: 154}, _}, 1_000
    assert_receive {:packet_sent, %FameUpdate{awarded_points: 1, total_fame: 1}, _}, 1_000
    assert Repo.get!(InventoryItem, weapon.id).refine == 10
    assert Repo.get!(InventoryItem, ore.id).amount == 1
    assert Repo.get!(Character, session.character.id).fame == 1
    assert get_player_state(session.pid).zeny == initial.zeny

    assert get_player_state(session.pid).stats.current_state.sp ==
             initial.stats.current_state.sp - cost

    reply(session)
    _settled = PlayerSession.get_state(session.pid)
    refute_receive {:packet_sent, %ProductionResult{}, _}, 100
    refute_receive {:packet_sent, %FameUpdate{}, _}, 100
    assert Repo.get!(InventoryItem, ore.id).amount == 1
  end

  test "cancel_wrong_skill_and_unoffered_reply_do_not_refund_or_attempt" do
    {session, weapon, ore} = start_smith()
    open(session)
    sp = get_player_state(session.pid).stats.current_state.sp
    simulate_incoming_message(session.pid, %SkillMenuReply{src_skill_id: 486, selected_id: 0})
    simulate_incoming_message(session.pid, %SkillMenuReply{src_skill_id: 477, selected_id: 99})
    assert PlayerSession.get_state(session.pid).pending_skill_menu != nil
    simulate_incoming_message(session.pid, %SkillMenuReply{src_skill_id: 477, cancel: true})
    assert PlayerSession.get_state(session.pid).pending_skill_menu == nil
    assert get_player_state(session.pid).stats.current_state.sp == sp
    assert Repo.get!(InventoryItem, weapon.id).refine == 9
    assert Repo.get!(InventoryItem, ore.id).amount == 2
  end

  test "replaced_same_nameid_row_is_rejected" do
    {session, weapon, ore} = start_smith()
    open(session)

    replacement =
      Repo.insert!(%InventoryItem{
        char_id: session.character.id,
        nameid: 1_101,
        amount: 1,
        refine: 9,
        identify: 1
      })

    :sys.replace_state(session.pid, fn state ->
      %{
        state
        | game_state: %{
            state.game_state
            | inventory: Map.put(state.game_state.inventory, 0, replacement)
          }
      }
    end)

    clear_packet_inbox()
    reply(session)
    assert eventually(fn -> PlayerSession.get_state(session.pid).pending_skill_menu == nil end)
    assert Repo.get!(InventoryItem, replacement.id).refine == 9
    assert Repo.get!(InventoryItem, weapon.id).refine == 9
    assert Repo.get!(InventoryItem, ore.id).amount == 2
    refute_receive {:packet_sent, %ProductionResult{}, _}, 100
  end

  test "equipped_after_offer_runs_lifecycle" do
    {session, weapon, _ore} = start_smith()
    force_roll(session, 0)
    open(session)

    simulate_incoming_message(session.pid, %EquipItem{
      index: PlayerState.client_index(0),
      position: 2
    })

    assert eventually(fn -> get_player_state(session.pid).inventory[0].equip == 2 end)

    assert :ok =
             PlayerSession.apply_status(session.pid, :sc_maxoverthrust,
               val1: 5,
               duration: 180_000
             )

    assert :ok = PlayerSession.apply_status(session.pid, :sc_aspersio, val1: 1, duration: 60_000)
    reply(session)
    assert_receive {:packet_sent, %ProductionResult{success: true}, _}, 1_000
    state = get_player_state(session.pid)
    assert state.inventory[0].equip == 2
    assert state.stats.equipment.right_hand == 1_101
    assert Repo.get!(InventoryItem, weapon.id).refine == 10
    refute StatusStorage.has_status?(:player, session.character.id, :sc_aspersio)

    assert StatusStorage.has_status?(:player, session.character.id, :sc_maxoverthrust) ==
             (GameMode.mode() == :pre_renewal)
  end

  test "empty_offer_preserves_pending_descriptor" do
    {session, _weapon, _ore} = start_smith()

    simulate_incoming_message(session.pid, %EquipItem{
      index: PlayerState.client_index(0),
      position: 2
    })

    assert eventually(fn -> get_player_state(session.pid).inventory[0].equip == 2 end)

    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: 279,
      level: 2,
      target_id: session.character.id
    })

    assert_receive {:packet_sent, %SkillMenu{src_skill_id: 279}, _}, 5_000
    pending = PlayerSession.get_state(session.pid).pending_skill_menu
    clear_packet_inbox()

    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: 477,
      level: 1,
      target_id: session.character.id
    })

    assert_receive {:packet_sent, %SkillMenu{src_skill_id: 477, entry_ids: []}, _}, 1_000
    assert PlayerSession.get_state(session.pid).pending_skill_menu == pending
    simulate_incoming_message(session.pid, %SkillMenuReply{src_skill_id: 279, cancel: true})
    assert PlayerSession.get_state(session.pid).pending_skill_menu == nil

    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: 477,
      level: 1,
      target_id: session.character.id
    })

    assert_receive {:packet_sent, %SkillMenu{src_skill_id: 477, entry_ids: []}, _}, 1_000
    reply(session)
    assert PlayerSession.get_state(session.pid).pending_skill_menu == nil
    refute_receive {:packet_sent, %ProductionResult{}, _}, 100
  end

  test "rollback_changes_no_inventory_status_or_fame" do
    {session, weapon, ore} = start_smith()
    force_roll(session, 0)
    open(session)

    simulate_incoming_message(session.pid, %EquipItem{
      index: PlayerState.client_index(0),
      position: 2
    })

    assert eventually(fn -> get_player_state(session.pid).inventory[0].equip == 2 end)

    assert :ok =
             PlayerSession.apply_status(session.pid, :sc_maxoverthrust,
               val1: 5,
               duration: 180_000
             )

    stub(Persistence, :update_item, fn row, attrs ->
      if row.id == weapon.id,
        do: {:error, :forced_failure},
        else: Repo.update(InventoryItem.changeset(row, attrs))
    end)

    Mimic.allow(Persistence, self(), session.pid)
    before = get_player_state(session.pid)
    clear_packet_inbox()
    reply(session)
    assert eventually(fn -> PlayerSession.get_state(session.pid).pending_skill_menu == nil end)
    assert get_player_state(session.pid).inventory == before.inventory
    assert StatusStorage.has_status?(:player, session.character.id, :sc_maxoverthrust)
    assert Repo.get!(InventoryItem, weapon.id).refine == 9
    assert Repo.get!(InventoryItem, ore.id).amount == 2
    assert Repo.get!(Character, session.character.id).fame == 0
    refute_receive {:packet_sent, %ProductionResult{}, _}, 100
    refute_receive {:packet_sent, %SpecialEffect{effect_id: 154}, _}, 100
  end

  test "failed_roll_consumes_ore_and_destroys_selected_weapon" do
    {session, weapon, ore} = start_smith()
    force_roll(session, 99)
    open(session)
    reply(session)
    assert_receive {:packet_sent, %ProductionResult{success: false}, _}, 1_000
    assert_receive {:packet_sent, %SpecialEffect{effect_id: 155}, _}, 1_000
    assert_receive {:packet_sent, %Emotion{type: 23}, _}, 1_000
    assert Repo.get(InventoryItem, weapon.id) == nil
    assert Repo.get!(InventoryItem, ore.id).amount == 1
    assert Repo.get!(Character, session.character.id).fame == 0
  end

  test "trade_warp_and_death_invalidate_attempts" do
    {session, weapon, ore} = start_smith()
    open(session)
    :sys.replace_state(session.pid, &%{&1 | trade: %{}})
    reply(session)
    assert PlayerSession.get_state(session.pid).pending_skill_menu == nil
    :sys.replace_state(session.pid, &%{&1 | trade: nil})
    open(session)
    PlayerSession.warp(session.pid, "prontera", 151, 150)
    assert eventually(fn -> PlayerSession.get_state(session.pid).pending_skill_menu == nil end)
    reply(session)
    open(session)
    PlayerSession.apply_damage(session.pid, 1_000_000)
    assert eventually(fn -> PlayerSession.get_state(session.pid).pending_skill_menu == nil end)
    reply(session)
    assert Repo.get!(InventoryItem, weapon.id).refine == 9
    assert Repo.get!(InventoryItem, ore.id).amount == 2
  end

  test "committed_refine_runs_card_cleanup_once_and_rollback_runs_none" do
    {session, weapon, ore} = start_smith(%{card0: 4_165, craft: nil})
    force_roll(session, 0)
    open(session)
    simulate_incoming_message(session.pid, %EquipItem{index: 2, position: 2})
    assert eventually(fn -> get_player_state(session.pid).inventory[0].equip == 2 end)
    before = get_player_state(session.pid).stats.current_state.sp

    stub(Persistence, :update_item, fn row, attrs ->
      if row.id == weapon.id,
        do: {:error, :forced_failure},
        else: Repo.update(InventoryItem.changeset(row, attrs))
    end)

    Mimic.allow(Persistence, self(), session.pid)
    reply(session)
    assert eventually(fn -> PlayerSession.get_state(session.pid).pending_skill_menu == nil end)
    assert get_player_state(session.pid).stats.current_state.sp == before
    assert Repo.get!(InventoryItem, ore.id).amount == 2

    stub(Persistence, :update_item, fn row, attrs ->
      Repo.update(InventoryItem.changeset(row, attrs))
    end)

    simulate_incoming_message(session.pid, %UnequipItem{index: 2})
    assert eventually(fn -> get_player_state(session.pid).inventory[0].equip == 0 end)
    open(session)
    simulate_incoming_message(session.pid, %EquipItem{index: 2, position: 2})
    assert eventually(fn -> get_player_state(session.pid).inventory[0].equip == 2 end)
    before = get_player_state(session.pid).stats.current_state.sp
    reply(session)
    assert_receive {:packet_sent, %ProductionResult{success: true}, _}, 1_000

    assert eventually(fn ->
             get_player_state(session.pid).stats.current_state.sp == before - 5
           end)

    assert Repo.get!(InventoryItem, weapon.id).refine == 10
    reply(session)
    _settled = PlayerSession.get_state(session.pid)
    assert get_player_state(session.pid).stats.current_state.sp == before - 5
  end

  defp force_roll(session, roll) do
    stub(RefineOps, :weapon_skill, fn state, index, id, rank ->
      RefineOps.weapon_skill(state, index, id, rank, success_roll: roll)
    end)

    Mimic.allow(RefineOps, self(), session.pid)
  end

  defp open(session) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: 477,
      level: 1,
      target_id: session.character.id
    })

    assert_receive {:packet_sent, %SkillMenu{src_skill_id: 477}, _}, 1_000
    pending = PlayerSession.get_state(session.pid).pending_skill_menu
    assert pending != nil
    pending
  end

  defp reply(session),
    do:
      simulate_incoming_message(session.pid, %SkillMenuReply{
        src_skill_id: 477,
        selected_id: 0,
        extra_ids: [999]
      })

  defp start_smith(weapon_attrs \\ %{}) do
    id = System.unique_integer([:positive])

    account =
      Repo.insert!(%Account{userid: "wr#{id}", user_pass: "unused", email: "wr@test.local"})

    character =
      Repo.insert!(%Character{
        account_id: account.id,
        char_num: 0,
        name: "Refiner#{id}",
        class: 4011,
        base_level: 99,
        job_level: 70,
        hp: 5_000,
        sp: 400,
        max_sp: 400,
        zeny: 100_000,
        learned_skills: %{"477" => 10, "279" => 2, "19" => 1},
        last_map: "prontera",
        last_x: 150,
        last_y: 150
      })

    {:ok, weapon} =
      Persistence.insert_item(
        character.id,
        Map.merge(
          %{
            nameid: 1_101,
            amount: 1,
            identify: 1,
            refine: 9,
            craft: ItemCraft.to_map(ItemCraft.forged(:neutral, 0, character.id))
          },
          weapon_attrs
        )
      )

    {:ok, ore} = Persistence.insert_item(character.id, %{nameid: 1_010, amount: 2})
    session = start_player_session(character: character)
    on_exit(fn -> end_player_session(session) end)
    clear_packet_inbox()
    {session, weapon, ore}
  end
end
