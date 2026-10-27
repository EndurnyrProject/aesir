defmodule Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  @moduletag :capture_log

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.EquipResult
  alias Aesir.Net.ItemBound
  alias Aesir.Net.SkillEffect
  alias Aesir.Net.SystemNotice
  alias Aesir.Net.UnequipResult
  alias Aesir.StatusActionFixture
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  test "publishes inventory changes after equip, replacement, and unequip commits" do
    :ok = Phoenix.PubSub.subscribe(Aesir.PubSub, "player:1000")

    game_state = PlayerState.new(%{character() | class: 1, base_level: 99})

    inventory = %{
      0 => %InventoryItem{nameid: 1101, amount: 1, identify: 1},
      1 => %InventoryItem{nameid: 1101, amount: 1, identify: 1}
    }

    state = %{connection_pid: self(), game_state: %{game_state | inventory: inventory}}
    test_pid = self()

    stub(InventoryOps, :apply_change, fn 1000, _old, new, _change -> {:ok, new} end)
    stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _game_state ->
      send(test_pid, :equipment_committed)
      :ok
    end)

    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    assert {:noreply, equipped} = EquipmentHandler.handle_equip(0, 2, state)
    assert_receive :equipment_committed
    assert_receive :inventory_changed

    assert {:noreply, replaced} = EquipmentHandler.handle_equip(1, 2, equipped)
    assert_receive :equipment_committed
    assert_receive :inventory_changed

    assert {:noreply, _unequipped} = EquipmentHandler.handle_unequip(1, replaced)
    assert_receive :equipment_committed
    assert_receive :inventory_changed

    assert {:noreply, _state} = EquipmentHandler.handle_equip(99, 2, state)
    assert {:noreply, _state} = EquipmentHandler.handle_unequip(99, state)

    stub(InventoryOps, :apply_change, fn 1000, _old, _new, _change ->
      {:error, :write_failed}
    end)

    assert {:noreply, ^state} = EquipmentHandler.handle_equip(0, 2, state)
    refute_receive :inventory_changed
  end

  test "sends an equip failure for an unidentified item" do
    game_state = PlayerState.new(%{character() | class: 1, base_level: 99})
    item = %InventoryItem{nameid: 1101, amount: 1, identify: 0}
    state = %{connection_pid: self(), game_state: %{game_state | inventory: %{0 => item}}}

    assert {:noreply, ^state} = EquipmentHandler.handle_equip(0, 2, state)

    assert_receive {:send, :gameplay, {:equip_result, %EquipResult{index: 2, result: 2}}}
  end

  test "refuses an equip change while an Arrow Vulcan cast holds it" do
    game_state = PlayerState.new(%{character() | class: 1, base_level: 99})
    item = %InventoryItem{nameid: 1101, amount: 1, identify: 1}

    state = %{
      connection_pid: self(),
      game_state: %{game_state | inventory: %{0 => item}},
      equip_lock_until: System.monotonic_time(:millisecond) + 60_000
    }

    assert {:noreply, ^state} = EquipmentHandler.handle_equip(0, 2, state)

    assert_receive {:send, :gameplay, {:equip_result, %EquipResult{index: 2, result: 2}}}
  end

  test "an elapsed Arrow Vulcan lock lets the equip change through" do
    game_state = PlayerState.new(%{character() | class: 1, base_level: 99})
    item = %InventoryItem{nameid: 1101, amount: 1, identify: 1}

    state = %{
      connection_pid: self(),
      game_state: %{game_state | inventory: %{0 => item}},
      equip_lock_until: System.monotonic_time(:millisecond) - 1
    }

    stub(InventoryOps, :apply_change, fn 1000, _old, new, _change -> {:ok, new} end)
    stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _game_state -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    assert {:noreply, _equipped} = EquipmentHandler.handle_equip(0, 2, state)
  end

  describe "an equip request in an NPC dialog" do
    @tag game_mode: :renewal
    test "renewal's default refuses it with the can't-equip notice and no equip result" do
      state = in_dialog(unidentified_sword_state())

      assert {:noreply, ^state} = EquipmentHandler.handle_equip(0, 2, state)

      assert_receive {:send, :gameplay,
                      {:system_notice, %SystemNotice{id: :SYSTEM_NOTICE_ID_CAN_NOT_EQUIP_ITEM}}}

      refute_received {:send, :gameplay, {:equip_result, _}}
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal's default lets it reach the equip checks" do
      state = in_dialog(unidentified_sword_state())

      assert {:noreply, ^state} = EquipmentHandler.handle_equip(0, 2, state)

      assert_receive {:send, :gameplay, {:equip_result, %EquipResult{index: 2, result: 2}}}
      refute_received {:send, :gameplay, {:system_notice, _}}
    end
  end

  describe "an equip request while the player cannot act" do
    for {label, busy} <- [
          {"trading", {:session, :trade, %{pid: nil}}},
          {"vending", {:game, :vending_shop, %{shop_id: "equip-fixture"}}},
          {"with an NPC shop window open", {:session, :npc_shop, 0x5800_0001}}
        ] do
      @busy busy
      test "#{label} is refused silently" do
        state = busy(unidentified_sword_state(), @busy)

        assert {:noreply, ^state} = EquipmentHandler.handle_equip(0, 2, state)
        assert {:noreply, ^state} = EquipmentHandler.handle_unequip(0, state)
        refute_received {:send, _, _}
      end

      test "#{label} with a storage window open reaches the equip checks" do
        state =
          unidentified_sword_state()
          |> busy(@busy)
          |> busy({:game, :storage, %{}})

        assert {:noreply, ^state} = EquipmentHandler.handle_equip(0, 2, state)
        assert_receive {:send, :gameplay, {:equip_result, %EquipResult{index: 2, result: 2}}}
      end
    end

    @tag game_mode: :renewal
    test "a refusing NPC dialog's notice comes before a shop window's silent refusal" do
      state = unidentified_sword_state() |> in_dialog() |> busy({:session, :npc_shop, 1})

      assert {:noreply, ^state} = EquipmentHandler.handle_unequip(0, state)

      assert_receive {:send, :gameplay,
                      {:system_notice, %SystemNotice{id: :SYSTEM_NOTICE_ID_CAN_NOT_EQUIP_ITEM}}}
    end

    test "an index outside the inventory is dropped without a reply" do
      state = unidentified_sword_state()
      assert {:noreply, ^state} = EquipmentHandler.handle_equip(10_000, 2, state)
      refute_received {:send, _, _}
    end
  end

  defp busy(state, {:session, key, value}), do: Map.put(state, key, value)

  defp busy(state, {:game, key, value}),
    do: Map.update!(state, :game_state, &Map.put(&1, key, value))

  defp unidentified_sword_state do
    game_state = PlayerState.new(%{character() | class: 1, base_level: 99})
    item = %InventoryItem{nameid: 1101, amount: 1, identify: 0}
    %{connection_pid: self(), game_state: %{game_state | inventory: %{0 => item}}}
  end

  defp in_dialog(state), do: Map.put(state, :interaction_lock, {self(), make_ref(), 0x5000_0001})

  test "rejects an equip while Divest Weapon blocks its slot" do
    game_state = PlayerState.new(%{character() | class: 1, base_level: 99})
    sword = %InventoryItem{nameid: 1101, amount: 1, identify: 1}
    game_state = %{game_state | inventory: %{0 => sword}}
    state = %{connection_pid: self(), game_state: game_state}

    :ok = UnitRegistry.register_player(game_state, self())

    assert :ok =
             StatusInterpreter.apply_status(:player, 1000, :sc_stripweapon,
               duration: 30_000,
               bypass_resistance: true
             )

    assert StatusInterpreter.equip_blocked?(:player, 1000, :right_hand)
    refute StatusInterpreter.equip_blocked?(:player, 1000, :armor)

    assert {:noreply, ^state} = EquipmentHandler.handle_equip(0, 2, state)

    assert_receive {:send, :gameplay, {:equip_result, %EquipResult{index: 2, result: 2}}}

    assert :ok = StatusInterpreter.remove_status(:player, 1000, :sc_stripweapon)
    refute StatusInterpreter.equip_blocked?(:player, 1000, :right_hand)

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    expect(InventoryOps, :apply_change, fn 1000, _old, new, {:equipped, 0, 2, []} ->
      {:ok, new}
    end)

    expect(Calculator, :calculate_stats, fn stats,
                                            1000,
                                            [%InventoryItem{nameid: 1101, equip: 2}] ->
      stats
    end)

    assert {:noreply, %{game_state: %{inventory: %{0 => %InventoryItem{equip: 2}}}}} =
             EquipmentHandler.handle_equip(0, 2, state)

    assert_receive {:send, :gameplay, {:equip_result, %EquipResult{index: 2, result: 0}}}
  end

  describe "a Divest request" do
    setup do
      stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
      stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
      stub(StatusSync, :send_params, fn _connection, _params -> :ok end)
      stub(StatusSync, :send_param, fn _connection, _param, _value -> :ok end)
      stub(Calculator, :calculate_stats, fn stats, 1000 -> stats end)
      stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)
      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      :ok
    end

    test "strips each worn, unprotected piece and both hands' weapons" do
      :ok = StatusStorage.apply_status(:player, 1000, :sc_cp_armor, duration: 30_000)

      state =
        strip_target(%{
          0 => %InventoryItem{nameid: 1201, amount: 1, identify: 1, equip: 2},
          1 => %InventoryItem{nameid: 1201, amount: 1, identify: 1, equip: 32},
          2 => %InventoryItem{nameid: 2301, amount: 1, identify: 1, equip: 16},
          3 => %InventoryItem{nameid: 2220, amount: 1, identify: 1, equip: 256}
        })

      stub(InventoryOps, :apply_change, fn 1000, _old, new, {:unequipped, index} ->
        send(self(), {:unequipped, index})
        {:ok, new}
      end)

      reject(&SkillHandler.report_cast_failure/3)

      assert {:noreply, stripped} =
               EquipmentHandler.handle_strip(
                 [:right_hand, :left_hand, :armor, :head_top],
                 strip_opts(report_to: 1234),
                 state
               )

      assert_received {:unequipped, 0}
      assert_received {:unequipped, 1}
      assert_received {:unequipped, 3}
      refute_received {:unequipped, 2}
      assert %InventoryItem{equip: 16} = stripped.game_state.inventory[2]

      assert StatusStorage.has_status?(:player, 1000, :sc_stripweapon)
      refute StatusStorage.has_status?(:player, 1000, :sc_stripshield)
      refute StatusStorage.has_status?(:player, 1000, :sc_striparmor)
      assert StatusStorage.has_status?(:player, 1000, :sc_striphelm)
    end

    test "a two-handed weapon goes once and leaves no shield to strip" do
      state =
        strip_target(%{0 => %InventoryItem{nameid: 1116, amount: 1, identify: 1, equip: 34}})

      expect(InventoryOps, :apply_change, fn 1000, _old, new, {:unequipped, 0} -> {:ok, new} end)

      assert {:noreply, _state} =
               EquipmentHandler.handle_strip([:right_hand, :left_hand], strip_opts([]), state)

      assert StatusStorage.has_status?(:player, 1000, :sc_stripweapon)
      refute StatusStorage.has_status?(:player, 1000, :sc_stripshield)
    end

    test "stripping nothing reports the failure only to a player caster" do
      state = strip_target(%{})
      reject(&InventoryOps.apply_change/4)
      expect(SkillHandler, :report_cast_failure, fn 217, 1234, :skill_failed -> :ok end)

      expect(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, packet ->
        assert %SkillEffect{skill_id: 217, target_id: 1000, result: 0} = packet
        :ok
      end)

      assert {:noreply, ^state} =
               EquipmentHandler.handle_strip(
                 [:armor],
                 strip_opts(report_to: 1234, origin: {"elsewhere", 1, 1}),
                 state
               )

      refute StatusStorage.has_status?(:player, 1000, :sc_striparmor)

      reject(&SkillHandler.report_cast_failure/3)

      assert {:noreply, ^state} =
               EquipmentHandler.handle_strip([:armor], strip_opts(report_to: nil), state)
    end

    test "a request to a session that is gone is dropped" do
      pid = spawn(fn -> :ok end)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}

      assert :ok = PlayerSession.strip_equip(pid, [:armor], strip_opts([]))
    end
  end

  defp strip_target(inventory) do
    game_state = PlayerState.new(%{character() | class: 12, base_level: 99})
    game_state = %{game_state | inventory: inventory}
    :ok = UnitRegistry.register_player(game_state, self())
    %{connection_pid: self(), game_state: game_state}
  end

  defp strip_opts(overrides) do
    Keyword.merge(
      [
        skill_id: 217,
        level: 5,
        kind: :divest,
        duration: 30_000,
        caster_id: 1234,
        source_type: :player,
        src_id: 1234,
        target_id: 1000,
        origin: {"prontera", 150, 150},
        report_to: nil
      ],
      overrides
    )
  end

  test "active status refuses equip and unequip without changing inventory" do
    Registry.register_module(StatusActionFixture)
    :ok = StatusStorage.apply_status(:player, 1000, StatusActionFixture.id(), duration: 30_000)

    game_state = PlayerState.new(%{character() | class: 1, base_level: 99})
    sword = %InventoryItem{nameid: 1101, amount: 1, identify: 1}
    worn = %InventoryItem{nameid: 1101, amount: 1, identify: 1, equip: 2}

    state = %{
      connection_pid: self(),
      game_state: %{game_state | inventory: %{0 => sword, 1 => worn}}
    }

    reject(&InventoryOps.apply_change/4)

    assert {:noreply, ^state} = EquipmentHandler.handle_equip(0, 2, state)
    assert_receive {:send, :gameplay, {:equip_result, %EquipResult{index: 2, result: 2}}}

    assert {:noreply, ^state} = EquipmentHandler.handle_unequip(1, state)
    assert_receive {:send, :gameplay, {:unequip_result, %UnequipResult{index: 3, result: 1}}}
  end

  test "binds an unbound bind-on-equip item and notifies the client" do
    game_state = PlayerState.new(character())
    item = %InventoryItem{nameid: 1101, amount: 1, identify: 1}
    state = %{connection_pid: self(), game_state: %{game_state | inventory: %{0 => item}}}

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    stub(ItemManagement, :get_item_by_id, fn 1101 ->
      {:ok, weapon_definition(1101, true)}
    end)

    expect(InventoryOps, :apply_change, fn 1000, _old, new, {:equipped, 0, 2, []} ->
      {:ok, new}
    end)

    expect(InventoryOps, :set_slot, fn 1000,
                                       inventory,
                                       0,
                                       %InventoryItem{bound: 1} = bound_item ->
      {:ok, Map.put(inventory, 0, bound_item)}
    end)

    expect(Calculator, :calculate_stats, fn stats,
                                            1000,
                                            [%InventoryItem{nameid: 1101, equip: 2}] ->
      stats
    end)

    assert {:noreply, %{game_state: %{inventory: %{0 => %InventoryItem{bound: 1, equip: 2}}}}} =
             EquipmentHandler.handle_equip(0, 2, state)

    assert_receive {:send, :gameplay, {:item_bound, %ItemBound{index: 2, bound: :BOUND_ACCOUNT}}}
    assert_receive {:send, :gameplay, {:equip_result, %EquipResult{index: 2, result: 0}}}
  end

  test "keeps the item equipped when bind persistence fails" do
    game_state = PlayerState.new(character())
    item = %InventoryItem{nameid: 1101, amount: 1, identify: 1}
    state = %{connection_pid: self(), game_state: %{game_state | inventory: %{0 => item}}}

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    stub(ItemManagement, :get_item_by_id, fn 1101 ->
      {:ok, weapon_definition(1101, true)}
    end)

    expect(InventoryOps, :apply_change, fn 1000, _old, new, {:equipped, 0, 2, []} ->
      {:ok, new}
    end)

    expect(InventoryOps, :set_slot, fn 1000, _inventory, 0, %InventoryItem{bound: 1} ->
      {:error, :write_failed}
    end)

    expect(Calculator, :calculate_stats, fn stats,
                                            1000,
                                            [%InventoryItem{nameid: 1101, equip: 2}] ->
      stats
    end)

    assert {:noreply, %{game_state: %{inventory: %{0 => %InventoryItem{bound: 0, equip: 2}}}}} =
             EquipmentHandler.handle_equip(0, 2, state)

    assert_receive {:send, :gameplay, {:equip_result, %EquipResult{index: 2, result: 0}}}
    refute_receive {:send, :gameplay, {:item_bound, %ItemBound{}}}
  end

  test "does not bind non-flagged or already-bound items" do
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    stub(ItemManagement, :get_item_by_id, fn
      1101 ->
        {:ok, weapon_definition(1101)}

      1102 ->
        {:ok, weapon_definition(1102, true)}
    end)

    stub(InventoryOps, :apply_change, fn 1000, _old, new, {:equipped, _index, 2, []} ->
      {:ok, new}
    end)

    reject(&InventoryOps.set_slot/4)
    stub(Calculator, :calculate_stats, fn stats, 1000, _equipped -> stats end)

    for {nameid, bound} <- [{1101, 0}, {1102, 1}] do
      game_state = PlayerState.new(character())
      item = %InventoryItem{nameid: nameid, amount: 1, identify: 1, bound: bound}
      state = %{connection_pid: self(), game_state: %{game_state | inventory: %{0 => item}}}

      assert {:noreply, %{game_state: %{inventory: %{0 => %InventoryItem{bound: ^bound}}}}} =
               EquipmentHandler.handle_equip(0, 2, state)

      assert_receive {:send, :gameplay, {:equip_result, %EquipResult{index: 2, result: 0}}}
      refute_receive {:send, :gameplay, {:item_bound, %ItemBound{}}}
    end
  end

  test "unequipping a two-handed sword removes Parrying" do
    game_state = PlayerState.new(character())
    sword = %InventoryItem{nameid: 1116, amount: 1, equip: 34, identify: 1}
    game_state = %{game_state | inventory: %{0 => sword}}
    :ok = StatusStorage.apply_status(:player, 1000, :sc_parrying, val1: 5, duration: 30_000)

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(UnitRegistry, :get_unit_info, fn :player, 1000 -> {:ok, %{stats: game_state.stats}} end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    expect(InventoryOps, :apply_change, fn 1000, _old, _new, {:unequipped, 0} ->
      {:ok, %{}}
    end)

    expect(Calculator, :calculate_stats, fn stats, 1000, [] -> stats end)

    state = %{connection_pid: self(), game_state: game_state}
    assert {:noreply, _state} = EquipmentHandler.handle_unequip(0, state)
    refute StatusStorage.has_status?(:player, 1000, :sc_parrying)
  end

  test "removes weapon-unequip statuses only after a successful weapon unequip" do
    game_state = PlayerState.new(character())
    weapon = %InventoryItem{nameid: 501, amount: 1, equip: 2}
    game_state = %{game_state | inventory: %{0 => weapon}}

    # Applied directly so end_on_start exclusion does not displace them; all
    # carry :remove_on_unequip_weapon and must drop together on the unequip.
    weapon_unequip_statuses = [
      :sc_aspersio,
      :sc_encpoison,
      :sc_fireweapon,
      :sc_waterweapon,
      :sc_windweapon,
      :sc_earthweapon
    ]

    for status <- weapon_unequip_statuses do
      :ok = StatusStorage.apply_status(:player, 1000, status, duration: 30_000)
    end

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(UnitRegistry, :get_unit_info, fn :player, 1000 -> {:ok, %{stats: game_state.stats}} end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    expect(InventoryOps, :apply_change, fn 1000, _old, _new, {:unequipped, 0} ->
      {:ok, %{}}
    end)

    expect(Calculator, :calculate_stats, fn stats, 1000, [] -> stats end)

    state = %{connection_pid: self(), game_state: game_state}
    assert {:noreply, _state} = EquipmentHandler.handle_unequip(0, state)

    for status <- weapon_unequip_statuses do
      refute StatusStorage.has_status?(:player, 1000, status)
    end
  end

  test "keeps weapon-unequip statuses after failures and non-weapon changes" do
    game_state = PlayerState.new(character())
    armor = %InventoryItem{nameid: 501, amount: 1, equip: 16}
    game_state = %{game_state | inventory: %{0 => armor}}

    :ok = StatusStorage.apply_status(:player, 1000, :sc_aspersio, duration: 30_000)

    state = %{connection_pid: self(), game_state: game_state}
    assert {:noreply, ^state} = EquipmentHandler.handle_unequip(99, state)
    assert {:noreply, ^state} = EquipmentHandler.handle_equip(99, 2, state)
    assert StatusStorage.has_status?(:player, 1000, :sc_aspersio)

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    expect(InventoryOps, :apply_change, fn 1000, _old, _new, {:unequipped, 0} ->
      {:ok, %{}}
    end)

    expect(Calculator, :calculate_stats, fn stats, 1000, [] -> stats end)

    assert {:noreply, _state} = EquipmentHandler.handle_unequip(0, state)
    assert StatusStorage.has_status?(:player, 1000, :sc_aspersio)
  end

  test "drops shield-gated toggles when the shield is unequipped" do
    game_state = PlayerState.new(character())
    shield = %InventoryItem{nameid: 2101, amount: 1, equip: 32, identify: 1}
    game_state = %{game_state | inventory: %{0 => shield}}

    shield_statuses = [:sc_autoguard, :sc_defender, :sc_reflectshield]
    for status <- shield_statuses, do: :ok = StatusStorage.apply_status(:player, 1000, status)

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(UnitRegistry, :get_unit_info, fn :player, 1000 -> {:ok, %{stats: game_state.stats}} end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    expect(InventoryOps, :apply_change, fn 1000, _old, _new, {:unequipped, 0} -> {:ok, %{}} end)
    # The stubbed recalc keeps the default (shield-less) equipment, so no shield
    # remains after the takeoff.
    expect(Calculator, :calculate_stats, fn stats, 1000, [] -> stats end)

    state = %{connection_pid: self(), game_state: game_state}
    assert {:noreply, _state} = EquipmentHandler.handle_unequip(0, state)

    for status <- shield_statuses, do: refute(StatusStorage.has_status?(:player, 1000, status))
  end

  test "keeps shield-gated toggles on a shield-to-shield swap" do
    game_state = PlayerState.new(character())
    old_shield = %InventoryItem{nameid: 2101, amount: 1, equip: 32, identify: 1}
    new_shield = %InventoryItem{nameid: 2101, amount: 1, equip: 0, identify: 1}
    game_state = %{game_state | inventory: %{0 => old_shield, 1 => new_shield}}

    :ok = StatusStorage.apply_status(:player, 1000, :sc_autoguard)

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    expect(InventoryOps, :apply_change, fn 1000, _old, new, {:equipped, 1, 32, _unequipped} ->
      {:ok, new}
    end)

    # A shield still occupies the left hand after the swap, so the real shield?
    # check reports a shield is worn and the toggle must survive.
    swapped_equipment = %{game_state.stats.equipment | left_hand: 2101}
    swapped_stats = %{game_state.stats | equipment: swapped_equipment}
    expect(Calculator, :calculate_stats, fn _stats, 1000, _equipped -> swapped_stats end)

    state = %{connection_pid: self(), game_state: game_state}
    assert {:noreply, _state} = EquipmentHandler.handle_equip(1, 32, state)

    assert StatusStorage.has_status?(:player, 1000, :sc_autoguard)
  end

  test "publishes recalculated maxima and clamped resources after equipment changes" do
    game_state = PlayerState.new(character())
    item = %InventoryItem{nameid: 501, amount: 1, equip: 2}
    game_state = %{game_state | party_id: 7, inventory: %{0 => item}}

    recalculated =
      game_state.stats
      |> put_in([Access.key!(:current_state), Access.key!(:hp)], 80)
      |> put_in([Access.key!(:current_state), Access.key!(:sp)], 40)
      |> put_in([Access.key!(:current_state), Access.key!(:ap)], 10)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_hp)], 80)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_sp)], 40)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_ap)], 10)

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection, _params -> :ok end)

    expect(InventoryOps, :apply_change, fn 1000, _old, _new, {:unequipped, 0} ->
      {:ok, %{}}
    end)

    expect(Calculator, :calculate_stats, fn _stats, 1000, [] -> recalculated end)

    expect(Manager, :sync_member, fn 7, 1000, member ->
      assert member == %Member{
               char_id: 1000,
               name: "Equipper",
               job_id: recalculated.progression.job_id,
               base_level: recalculated.progression.base_level,
               hp: 80,
               max_hp: 80,
               sp: 40,
               max_sp: 40,
               ap: 10,
               max_ap: 10,
               online: true,
               map_name: "prontera"
             }

      {:ok, %{}}
    end)

    state = %{connection_pid: self(), game_state: game_state}

    assert {:noreply, %{game_state: %{stats: ^recalculated}}} =
             EquipmentHandler.handle_unequip(0, state)
  end

  test "refreshes and publishes walk speed after an equipment change" do
    game_state = PlayerState.new(character())
    item = %InventoryItem{nameid: 501, amount: 1, equip: 2}
    game_state = %{game_state | inventory: %{0 => item}, walk_speed: 150}

    speeded =
      put_in(game_state.stats, [Access.key!(:modifiers), Access.key!(:equipment)], %{
        movement_speed: 25
      })

    test_pid = self()

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)

    stub(StatusSync, :send_params, fn _connection, params ->
      send(test_pid, {:params, params})
      :ok
    end)

    expect(InventoryOps, :apply_change, fn 1000, _old, _new, {:unequipped, 0} -> {:ok, %{}} end)
    expect(Calculator, :calculate_stats, fn _stats, 1000, [] -> speeded end)

    state = %{connection_pid: self(), game_state: game_state}

    assert {:noreply, %{game_state: %{walk_speed: 112}}} =
             EquipmentHandler.handle_unequip(0, state)

    assert_receive {:params, params}
    assert params[StatusParams.speed()] == 112
  end

  defp weapon_definition(id, bind_on_equip \\ false) do
    %ItemDefinition{
      id: id,
      aegis_name: "Sword#{id}",
      name: "Sword",
      type: :weapon,
      locations: [:right_hand],
      bind_on_equip: bind_on_equip
    }
  end

  defp character do
    %Character{
      id: 1000,
      account_id: 2000,
      name: "Equipper",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
  end
end
