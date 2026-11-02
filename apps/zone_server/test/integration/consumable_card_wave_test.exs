defmodule Aesir.ZoneServer.Integration.ConsumableCardWaveTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.EquipItem
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.StatusChange
  alias Aesir.Net.UnequipItem
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @right_hand EquipLocation.location_bit(:right_hand)

  setup do
    ScriptCompiler.compile_all!()
    :ok
  end

  test "temporary card ingress changes real battle damage, coexists with worn cards and survives stale expiry",
       %{status_tick_manager: manager} do
    character = character()

    assert {:ok, weapon} =
             Persistence.insert_item(character.id, %{
               nameid: 1208,
               amount: 1,
               identify: 1,
               equip: @right_hand,
               card0: 4121
             })

    for id <- [14_597, 14_598] do
      assert {:ok, _} =
               Persistence.insert_item(character.id, %{nameid: id, amount: 2, identify: 1})
    end

    player = start_character(character)
    mob = start_mob_session(position: {151, 150}, atk: 100, atk2: 100, hp: 10_000, max_hp: 10_000)
    on_exit(fn -> end_mob_session(mob) end)
    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :hit end)
    id = player.character.id
    baseline = get_player_state(player.pid).stats
    assert baseline.modifiers.equipment.hit == 100
    assert [%{id: worn_id}] = baseline.worn_items
    assert worn_id == weapon.id
    normal_damage = weapon_skill_hit(mob, player)
    flush_packets()

    use_item(player, 14_598)
    assert PlayerState.get_element(get_player_state(player.pid)) == {:ghost, 1}
    ghost = StatusStorage.get_status(:player, id, :sc_itemscript)
    ghost_damage = weapon_skill_hit(mob, player)

    assert ghost_damage > 0 and ghost_damage < normal_damage,
           "expected Ghostring to reduce a positive hit, normal=#{normal_damage}, ghost=#{ghost_damage}"

    assert [%StatusChange{efst: 302, on: true, val1: 0, val2: 0, val3: 0}] =
             collect_packets_of_type(StatusChange)

    use_item(player, 14_597)
    phreeoni = StatusStorage.get_status(:player, id, :sc_itemscript)
    assert phreeoni.val1 == 4121
    assert get_player_state(player.pid).stats.combat_stats.hit == baseline.combat_stats.hit + 100
    assert get_player_state(player.pid).stats.modifiers.equipment.hit == 200
    assert [%{id: ^worn_id}] = get_player_state(player.pid).stats.worn_items
    assert [%StatusChange{efst: 248, on: true}] = collect_packets_of_type(StatusChange)
    assert PlayerState.get_element(get_player_state(player.pid)) == {:neutral, 1}

    key = {:player, id, :sc_itemscript}
    send(manager, {:status_timer, key, ghost.generation, ghost.expires_at})
    :sys.get_state(manager)
    assert StatusStorage.get_status(:player, id, :sc_itemscript) == phreeoni
    stats = get_player_state(player.pid).stats
    use_item(player, 14_598)
    assert StatusStorage.get_status(:player, id, :sc_itemscript) == phreeoni
    assert get_player_state(player.pid).stats.generation == stats.generation
    assert get_player_state(player.pid).stats.combat_stats.hit == stats.combat_stats.hit
    assert collect_packets_of_type(StatusChange) == []
    refute Enum.any?(Persistence.load_inventory(id), &(&1.nameid == 14_598))

    {index, _} =
      Enum.find(get_player_state(player.pid).inventory, fn {_index, row} ->
        row.id == weapon.id
      end)

    simulate_incoming_message(player.pid, %UnequipItem{index: PlayerState.client_index(index)})
    assert eventually(fn -> get_player_state(player.pid).stats.worn_items == [] end)
    assert get_player_state(player.pid).stats.modifiers.equipment.hit == 100

    simulate_incoming_message(player.pid, %EquipItem{
      index: PlayerState.client_index(index),
      position: @right_hand
    })

    assert eventually(fn -> get_player_state(player.pid).stats.modifiers.equipment.hit == 200 end)
    assert StatusStorage.get_status(:player, id, :sc_itemscript) == phreeoni
    expire_card(player)
    assert get_player_state(player.pid).stats.modifiers.equipment.hit == 100
    assert get_player_state(player.pid).stats.combat_stats.hit == baseline.combat_stats.hit
    assert [%{id: ^worn_id}] = get_player_state(player.pid).stats.worn_items

    assert [%StatusChange{efst: 248, on: false, val1: 0, val2: 0, val3: 0}] =
             collect_packets_of_type(StatusChange)
  end

  @tag game_mode: :pre_renewal, integration_re: false
  test "a pre-renewal Tao Gunka scroll refolds without equipment and expiry clamps current HP" do
    character = character()

    assert {:ok, _} =
             Persistence.insert_item(character.id, %{nameid: 14_602, amount: 1, identify: 1})

    player = start_character(character)
    baseline = get_player_state(player.pid).stats
    use_item(player, 14_602)
    boosted = get_player_state(player.pid).stats
    assert boosted.worn_items == []
    assert boosted.derived_stats.max_hp == baseline.derived_stats.max_hp * 2
    assert boosted.current_state.hp == baseline.current_state.hp
    assert {:ok, _} = PlayerSession.script_apply(player.pid, {:percent_heal, 100, 100})
    assert get_player_state(player.pid).stats.current_state.hp == boosted.derived_stats.max_hp
    expire_card(player)
    cleared = get_player_state(player.pid).stats
    assert cleared.derived_stats.max_hp == baseline.derived_stats.max_hp
    assert cleared.current_state.hp == baseline.derived_stats.max_hp
    assert cleared.card_unequip_effects == %{}
    assert PlayerSession.get_state(player.pid).applied_card_unequip_effects == %{}
    assert cleared.worn_items == []
    assert Persistence.load_inventory(character.id) == []
  end

  defp weapon_skill_hit(mob, player) do
    before_hp = get_player_state(player.pid).stats.current_state.hp
    :rand.seed(:exsss, {101, 103, 107})

    assert :ok =
             Combat.execute_skill_attack(get_mob_state(mob.pid), {:player, player.character.id},
               skill_id: 5,
               skill_level: 1,
               skill_ratio: 130,
               hit_rate_bonus_pct: 5,
               skip_crit: true
             )

    assert eventually(fn -> get_player_state(player.pid).stats.current_state.hp < before_hp end)
    before_hp - get_player_state(player.pid).stats.current_state.hp
  end

  defp use_item(player, nameid) do
    {index, _} =
      Enum.find(get_player_state(player.pid).inventory, fn {_index, row} ->
        row.nameid == nameid
      end)

    simulate_incoming_message(player.pid, %UseItem{index: PlayerState.client_index(index)})
    PlayerSession.get_state(player.pid)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
  end

  defp expire_card(player) do
    id = player.character.id
    generation = get_player_state(player.pid).stats.generation

    :ok =
      StatusStorage.update_status(
        :player,
        id,
        :sc_itemscript,
        &%{&1 | expires_at: System.monotonic_time(:millisecond) - 1}
      )

    StatusTickManager.force_tick()

    assert eventually(fn ->
             not StatusStorage.has_status?(:player, id, :sc_itemscript) and
               get_player_state(player.pid).stats.generation > generation
           end)
  end

  defp start_character(character) do
    player = start_player_session(character: character)
    on_exit(fn -> if Process.alive?(player.pid), do: GenServer.stop(player.pid, :normal) end)
    player
  end

  defp character do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "cc#{unique}",
        user_pass: "password",
        email: "cc#{unique}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "CC#{unique}",
      class: 0,
      base_level: 99,
      job_level: 1,
      learned_skills: %{"1" => 3},
      str: 1,
      agi: 1,
      vit: 20,
      int: 1,
      dex: 1,
      luk: 0,
      hp: 10_000,
      sp: 50,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      save_map: "prontera",
      save_x: 150,
      save_y: 150
    })
    |> Repo.insert!()
  end
end
