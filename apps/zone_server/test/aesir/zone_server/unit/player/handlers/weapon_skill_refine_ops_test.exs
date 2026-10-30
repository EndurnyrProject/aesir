defmodule Aesir.ZoneServer.Unit.Player.Handlers.WeaponSkillRefineOpsTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.Refine.WeaponSkill
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Mimic.copy(Persistence)

    account =
      Repo.insert!(%Account{
        userid: "skill-refine",
        user_pass: "unused",
        email: "refine@test.local"
      })

    character =
      Repo.insert!(%Character{
        account_id: account.id,
        char_num: 0,
        name: "SkillRefiner",
        class: 10,
        base_level: 99,
        job_level: 70,
        zeny: 10_000,
        last_map: "prontera",
        last_x: 100,
        last_y: 100
      })

    stub(RefineDatabase, :level_info, fn :weapon, level, next ->
      {:ok, ore} = WeaponSkill.material(level)

      %{
        bonus: 200 * next,
        randombonus_max: 0,
        chances: %{normal: %{rate: 5_000, material_nameid: ore}}
      }
    end)

    %{player: PlayerState.new(character)}
  end

  test "skill_refine_spends_one_ore_and_no_attempt_zeny", %{player: player} do
    for {roll, outcome} <- [{0, {:ok, :success, 4}}, {99, {:ok, :broke}}] do
      state =
        holding(player,
          refine: 3,
          card0: 4_001,
          card1: 4_002,
          bound: 1,
          random_options: [%{id: 1, value: 5, param: 0}],
          craft: ItemCraft.to_map(ItemCraft.forged(:fire, 1, player.character_id))
        )

      item = state.inventory[0]
      ore = state.inventory[1]
      {made, result} = RefineOps.weapon_skill(state, 0, item.id, 10, success_roll: roll)
      assert result == outcome
      assert made.zeny == state.zeny
      assert made.fame == 0
      assert made.stats.current_state.sp == state.stats.current_state.sp
      assert made.inventory[1].amount == 1
      assert Repo.get!(InventoryItem, ore.id).amount == 1
      assert made.pending_inventory_persist == []

      if roll == 0 do
        assert made.inventory[0].id == item.id

        for field <- [:card0, :card1, :random_options, :craft, :bound] do
          assert Map.fetch!(made.inventory[0], field) == Map.fetch!(item, field)
        end

        assert Repo.get!(InventoryItem, item.id).refine == 4
        assert made.pending_inventory_notify == [{:removed, 1, 1}, {:added, 0, made.inventory[0]}]
      else
        refute Map.has_key?(made.inventory, 0)
        assert Repo.get(InventoryItem, item.id) == nil
        assert made.pending_inventory_notify == [{:removed, 1, 1}, {:removed, 0, 1}]
      end
    end
  end

  test "replaced_same_nameid_row_is_rejected", %{player: player} do
    state = holding(player)
    expected = state.inventory[0].id

    replacement =
      Repo.insert!(%InventoryItem{
        char_id: player.character_id,
        nameid: 1_101,
        amount: 1,
        identify: 1
      })

    state = %{state | inventory: Map.put(state.inventory, 0, replacement)}
    assert {^state, {:error, :no_item}} = RefineOps.weapon_skill(state, 0, expected, 10)
    assert Repo.get!(InventoryItem, state.inventory[1].id).amount == 2
    assert Repo.get!(InventoryItem, replacement.id).refine == 0
  end

  test "rollback_keeps_inventory_and_fame", %{player: player} do
    for position <- [0, 1] do
      state =
        holding(player,
          refine: 9,
          craft: ItemCraft.to_map(ItemCraft.forged(:neutral, 0, player.character_id))
        )

      failed_id = state.inventory[position].id

      stub(Persistence, :update_item, fn row, attrs ->
        if row.id == failed_id,
          do: {:error, :forced_failure},
          else: Repo.update(InventoryItem.changeset(row, attrs))
      end)

      assert {^state, {:error, :forced_failure}} =
               RefineOps.weapon_skill(state, 0, state.inventory[0].id, 10, success_roll: 0)

      assert Repo.get!(InventoryItem, state.inventory[0].id).refine == 9
      assert Repo.get!(InventoryItem, state.inventory[1].id).amount == 2
      assert state.pending_fame_awards == []
      assert state.pending_inventory_notify == []
    end
  end

  test "equipped_after_offer_runs_lifecycle", %{player: player} do
    for roll <- [0, 99] do
      state = holding(player, refine: 3, equip: 2)

      :ok =
        StatusStorage.apply_status(:player, player.character_id, :sc_maxoverthrust,
          val1: 5,
          val2: 100
        )

      :ok = StatusStorage.apply_status(:player, player.character_id, :sc_aspersio)

      {made, result} =
        RefineOps.weapon_skill(state, 0, state.inventory[0].id, 10, success_roll: roll)

      assert StatusStorage.has_status?(:player, player.character_id, :sc_maxoverthrust) ==
               (GameMode.mode() == :pre_renewal)

      refute StatusStorage.has_status?(:player, player.character_id, :sc_aspersio)

      if roll == 0 do
        assert result == {:ok, :success, 4}
        assert made.inventory[0].equip == 2
        assert made.stats.equipment.right_hand == 1_101
        assert made.stats.combat_stats.atk > state.stats.combat_stats.atk
      else
        assert result == {:ok, :broke}
        assert made.stats.equipment.right_hand == nil
      end
    end
  end

  test "rollback_keeps_equipment_and_statuses", %{player: player} do
    state = holding(player, equip: 2)

    :ok =
      StatusStorage.apply_status(:player, player.character_id, :sc_maxoverthrust,
        val1: 5,
        val2: 100
      )

    stub(Persistence, :delete_item, fn _row -> {:error, :forced_failure} end)

    assert {^state, {:error, :forced_failure}} =
             RefineOps.weapon_skill(state, 0, state.inventory[0].id, 10, success_roll: 99)

    assert Repo.get!(InventoryItem, state.inventory[0].id).equip == 2
    assert Repo.get!(InventoryItem, state.inventory[1].id).amount == 2
    assert StatusStorage.has_status?(:player, player.character_id, :sc_maxoverthrust)
    refute_received {:send, _, _}
  end

  test "own_forged_ten_awards_once_after_commit", %{player: player} do
    {:ok, definition} = Items.by_id(1_101)

    for {level, points} <- [{1, 1}, {2, 25}, {3, 1_000}, {4, 0}], own? <- [true, false] do
      stub(Items, :by_id, fn 1_101 -> {:ok, %{definition | weapon_level: level}} end)
      maker = if own?, do: player.character_id, else: player.character_id + 1
      {:ok, ore} = WeaponSkill.material(level)

      state =
        holding(
          player,
          [refine: 9, craft: ItemCraft.to_map(ItemCraft.forged(:neutral, 0, maker))],
          ore
        )

      assert {made, {:ok, :success, 10}} =
               RefineOps.weapon_skill(state, 0, state.inventory[0].id, 10, success_roll: 0)

      expected = if own?, do: points, else: 0
      assert made.fame == expected
      assert length(made.pending_fame_awards) == if(expected > 0, do: 1, else: 0)

      assert {^made, {:error, :max_refine}} =
               RefineOps.weapon_skill(made, 0, state.inventory[0].id, 10, success_roll: 0)
    end
  end

  test "left_hand_weapon_removal_runs_the_shared_unequip_hook", %{player: player} do
    state = holding(player, equip: 32)
    :ok = StatusStorage.apply_status(:player, player.character_id, :sc_aspersio)

    assert {:noreply, result} =
             EquipmentHandler.handle_unequip(0, %{game_state: state, connection_pid: self()})

    refute StatusStorage.has_status?(:player, player.character_id, :sc_aspersio)
    assert result.game_state.inventory[0].equip == 0
  end

  test "depleted_ore_and_break_writes_roll_back", %{player: player} do
    for position <- [0, 1] do
      state = holding(player)
      ore = state.inventory[1] |> InventoryItem.changeset(%{amount: 1}) |> Repo.update!()
      state = %{state | inventory: Map.put(state.inventory, 1, ore)}
      failed_id = state.inventory[position].id

      stub(Persistence, :delete_item, fn row ->
        if row.id == failed_id, do: {:error, :forced_failure}, else: Repo.delete(row)
      end)

      assert {^state, {:error, :forced_failure}} =
               RefineOps.weapon_skill(state, 0, state.inventory[0].id, 10, success_roll: 99)

      assert Repo.get!(InventoryItem, ore.id).amount == 1
      assert Repo.get!(InventoryItem, state.inventory[0].id).refine == 0
    end
  end

  test "third_job_bonus_uses_job_metadata", %{player: player} do
    {:ok, mechanic} = AvailableJobs.job_name_to_id(:mechanic)

    for {job, expected} <- [{10, {:ok, :broke}}, {mechanic, {:ok, :success, 1}}] do
      state = holding(player)
      progression = %{state.stats.progression | job_id: job, job_level: 1}
      state = %{state | stats: %{state.stats | progression: progression}}

      assert {_made, ^expected} =
               RefineOps.weapon_skill(state, 0, state.inventory[0].id, 10, success_roll: 55)
    end
  end

  defp holding(player, attrs \\ [], ore \\ 1_010) do
    item =
      Repo.insert!(
        struct!(
          %InventoryItem{char_id: player.character_id, nameid: 1_101, amount: 1, identify: 1},
          attrs
        )
      )

    material = Repo.insert!(%InventoryItem{char_id: player.character_id, nameid: ore, amount: 2})
    equipped = if item.equip == 0, do: [], else: [item]
    stats = Calculator.calculate_stats(player.stats, player.character_id, equipped)
    state = %{player | inventory: %{0 => item, 1 => material}, stats: stats}
    :ok = UnitRegistry.register_player(state, self())
    state
  end
end
