defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.ItemscriptScrollsTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.StatusChange
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ItemHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    player =
      PlayerState.new(%Character{
        id: 7_713,
        account_id: 7_713,
        name: "Card scroll",
        class: 0,
        sex: "M",
        base_level: 1,
        job_level: 1,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 40,
        sp: 11,
        last_map: "prontera",
        last_x: 100,
        last_y: 100
      })

    :ok = UnitRegistry.register_player(player, self())
    %{state: %SessionState{game_state: player, connection_pid: self()}}
  end

  test "six complete pre-renewal source scripts execute inline with exact card values and durations",
       %{state: state} do
    install_scrolls()
    baseline_hit = state.game_state.stats.combat_stats.hit

    for {item_id, card_id, duration, icon, _script} <- scrolls() do
      before = System.monotonic_time(:millisecond)
      {:noreply, used} = use_scroll(state, item_id)
      after_use = System.monotonic_time(:millisecond)
      held = StatusStorage.get_status(:player, state.game_state.character_id, :sc_itemscript)
      assert {held.val1, held.val2, held.val3, held.val4} == {card_id, icon, 0, 0}
      assert held.expires_at >= before + duration
      assert held.expires_at <= after_use + duration
      assert used.game_state.inventory[0].amount == 2
      assert used.game_state.stats.generation == state.game_state.stats.generation + 1
      assert used.game_state.stats.worn_items == []

      assert [%StatusChange{efst: ^icon, val1: 0, val2: 0, val3: 0}] =
               StatusDisplay.active_icons(:player, state.game_state.character_id)

      case card_id do
        4121 -> assert used.game_state.stats.combat_stats.hit == baseline_hit + 100
        4047 -> assert PlayerState.get_element(used.game_state) == {:ghost, 1}
        _ -> :ok
      end

      assert :ok =
               Interpreter.remove_status(:player, state.game_state.character_id, :sc_itemscript)
    end

    for script <- [
          ~s(specialeffect2 EF_LIGHTSPHERE; bonus_script "{ bonus bMaxHPrate,100; bonus bDefRate,-50; bonus bMdefRate,-50; }",180,0,0,EFST_MVPCARD_TAOGUNKA;),
          ~s(specialeffect2 EF_SPELLBREAKER; bonus_script "{ bonus bNoGemStone; bonus bUseSPrate,25; }",180,0,0,EFST_MVPCARD_MISTRESS;),
          ~s(specialeffect2 EF_LIGHTSPHERE; bonus_script "{ bonus2 bResEff,Eff_Stun,10000; }",180,0,0,EFST_MVPCARD_ORCHERO;),
          ~s(specialeffect2 EF_LIGHTSPHERE; bonus_script "{ bonus bShortWeaponDamageReturn,30; }",180,0,0,EFST_MVPCARD_ORCLORD;)
        ] do
      assert {:error, _} = Transpiler.transpile(script)
    end
  end

  test "retained card scroll spends the item without refresh and stale expiry cannot end replacement",
       %{state: state} do
    install_scrolls()
    id = state.game_state.character_id
    assert {:noreply, tao} = use_scroll(state, 14_602)
    original = StatusStorage.get_status(:player, id, :sc_itemscript)
    held = %{original | expires_at: System.monotonic_time(:millisecond) + 10_000}
    assert StatusStorage.replace_status_if_current(:player, id, :sc_itemscript, original, held)
    assert_received {:area, %StatusChange{efst: 368, on: true}}

    assert {:noreply, retained} = use_scroll(tao, 14_598)
    assert retained.game_state.inventory[0].amount == 2
    assert retained.game_state.stats == tao.game_state.stats
    assert StatusStorage.get_status(:player, id, :sc_itemscript) == held
    assert_received {:send, :gameplay, {:item_use_result, %ItemUseResult{ok: true}}}
    refute_received {:area, %StatusChange{}}

    before_refresh = System.monotonic_time(:millisecond)
    assert {:noreply, refreshed} = use_scroll(retained, 14_602)
    after_refresh = System.monotonic_time(:millisecond)
    newer = StatusStorage.get_status(:player, id, :sc_itemscript)
    assert newer.expires_at >= before_refresh + 180_000
    assert newer.expires_at <= after_refresh + 180_000
    assert newer.generation != held.generation
    assert refreshed.game_state.stats.generation == retained.game_state.stats.generation + 1
    assert_received {:area, %StatusChange{efst: 368, on: true}}
    refute_received {:area, %StatusChange{on: false}}
    assert [] == Interpreter.expire_status_events_if_current(:player, id, :sc_itemscript, held)
    assert StatusStorage.get_status(:player, id, :sc_itemscript) == newer

    assert {:reply, :ok, cleared} = StatusManager.handle_remove_status(:sc_itemscript, refreshed)
    assert_received {:area, %StatusChange{efst: 368, on: false}}
    assert {:noreply, ghost} = use_scroll(cleared, 14_598)
    old_ghost = StatusStorage.get_status(:player, id, :sc_itemscript)
    assert_received {:area, %StatusChange{efst: 302, on: true}}
    assert {:noreply, replacement} = use_scroll(ghost, 14_602)
    replacement_entry = StatusStorage.get_status(:player, id, :sc_itemscript)
    assert replacement_entry.val1 == 4302
    assert replacement.game_state.stats.generation == ghost.game_state.stats.generation + 1
    assert_received {:area, %StatusChange{efst: 368, on: true}}
    refute_received {:area, %StatusChange{on: false}}

    assert [] ==
             Interpreter.expire_status_events_if_current(:player, id, :sc_itemscript, old_ghost)

    key = {:player, id, :sc_itemscript}

    timer_state = %StatusTickManager.State{
      timers: %{key => {make_ref(), old_ghost.generation, old_ghost.expires_at}}
    }

    assert {:noreply, rearmed} =
             StatusTickManager.handle_info(
               {:status_timer, key, old_ghost.generation, old_ghost.expires_at},
               timer_state
             )

    {_ref, generation, due} = rearmed.timers[key]
    assert generation == replacement_entry.generation
    assert due == replacement_entry.expires_at
    assert StatusStorage.get_status(:player, id, :sc_itemscript) == replacement_entry
    refute_received {:area, %StatusChange{on: false}}
    assert length(StatusStorage.get_unit_statuses(:player, id)) == 1
  end

  defp scrolls do
    [
      {14_597, 4121, 180_000, 248, "sc_start2 SC_ITEMSCRIPT,180000,4121,EFST_FOOD_BASICHIT;"},
      {14_598, 4047, 60_000, 302, "sc_start2 SC_ITEMSCRIPT,60000,4047,EFST_ARMOR_PROPERTY;"},
      {14_602, 4302, 180_000, 368, "sc_start2 SC_ITEMSCRIPT,180000,4302,EFST_MVPCARD_TAOGUNKA;"},
      {14_603, 4132, 180_000, 369, "sc_start2 SC_ITEMSCRIPT,180000,4132,EFST_MVPCARD_MISTRESS;"},
      {14_604, 4143, 60_000, 370, "sc_start2 SC_ITEMSCRIPT,60000,4143,EFST_MVPCARD_ORCHERO;"},
      {14_605, 4135, 180_000, 371, "sc_start2 SC_ITEMSCRIPT,180000,4135,EFST_MVPCARD_ORCLORD;"}
    ]
  end

  defp install_scrolls do
    definitions =
      Map.new(scrolls(), fn {id, _card, _duration, _icon, script} ->
        {:ok, source} = Transpiler.transpile(script)
        {:ok, definition} = Items.by_id(id)
        {id, %{definition | on_use: source}}
      end)

    :ok = ScriptCompiler.compile_all!(Map.values(definitions))

    stub(Items, :by_id, fn id ->
      case Map.fetch(definitions, id) do
        {:ok, definition} -> {:ok, definition}
        :error -> call_original(Items, :by_id, [id])
      end
    end)

    Mimic.copy(InventoryOps)

    stub(InventoryOps, :remove, fn _id, inventory, index, count ->
      Inventory.remove(inventory, index, count)
    end)

    owner = self()
    stub(SpatialIndex, :get_unit_position, fn _, _ -> {:ok, {100, 100, "prontera"}} end)

    stub(Broadcast, :to_in_range, fn _, _, _, _, packet, _ ->
      send(owner, {:area, packet})
      :ok
    end)
  end

  defp use_scroll(state, item_id) do
    inventory = %{0 => %InventoryItem{id: item_id, nameid: item_id, amount: 3}}
    player = %{state.game_state | inventory: inventory}
    :ok = UnitRegistry.update_unit_state(:player, player.character_id, player)
    ItemHandler.handle_use_item(2, %{state | game_state: player})
  end

  test "card scroll syntax resolves only known icons and preserves rate and flags" do
    assert Resolver.resolve_status_icon("EFST_FOOD_BASICHIT") == {:ok, 248}
    assert Resolver.resolve_status_icon("EFST_ARMOR_PROPERTY") == {:ok, 302}

    for symbol <- ["EFST_NOT_A_REAL_ICON", "EFST_id", "food_basichit"] do
      assert Resolver.resolve_status_icon(symbol) == {:error, {:unknown_symbol, symbol}}
    end

    assert {:ok, "sc_start(ctx, :sc_itemscript, 180000, [4121, 248, 0, 0])"} =
             Transpiler.transpile("sc_start2 SC_ITEMSCRIPT,180000,4121,EFST_FOOD_BASICHIT;")

    assert {:ok, "sc_start(ctx, :sc_itemscript, 60000, [4047, 302, 0, 0], 7500, 1)"} =
             Transpiler.transpile(
               "sc_start2 SC_ITEMSCRIPT,60000,4047,EFST_ARMOR_PROPERTY,7500,1;"
             )

    for script <- [
          "sc_start2 SC_ITEMSCRIPT,60000,4047,EFST_NOT_A_REAL_ICON;",
          "sc_start2 SC_ITEMSCRIPT,60000,4047;",
          "sc_start2 SC_ITEMSCRIPT,60000,4047,302,10000,0,42;",
          "sc_start2 SC_ITEMSCRIPT,60000,4047,302; unsupported_command;"
        ] do
      assert {:error, _} = Transpiler.transpile(script)
    end

    for script <- [
          "sc_start2 SC_ITEMSCRIPT,60000,4047,EFST_ARMOR_PROPERTY;",
          "sc_end SC_ITEMSCRIPT;",
          "itemheal 100,0;"
        ] do
      assert {:error, _} = Transpiler.transpile_equip(script, :equip)
    end
  end
end
