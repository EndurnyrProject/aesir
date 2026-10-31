defmodule Aesir.ZoneServer.Script.ItemVisualRuntimeTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Auth
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.GroundSkill
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.SkillDamage
  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ItemHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  setup context do
    Aesir.TestEtsSetup.setup_ets_tables(context)
    test = self()
    stub(Broadcast, :to_in_range, fn _, _, _, _, packet -> send(test, {:visual, packet}) end)

    player =
      PlayerState.new(%Character{
        id: 1001,
        account_id: 1001,
        name: "Visual",
        sex: "M",
        class: 0,
        base_level: 10,
        job_level: 1,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        last_map: "prontera",
        last_x: 150,
        last_y: 150
      })

    :ok = UnitRegistry.register_unit(:player, 1001, PlayerState, player, self())
    %{state: %SessionState{game_state: player, connection_pid: self()}}
  end

  test "damage and ground visuals use their own messages without casting", %{state: state} do
    ctx = Ctx.from_session(state, {:item, 12215})
    assert Dsl.skilleffect(ctx, 5, 0).game_state == state.game_state

    assert_receive {:visual,
                    %SkillDamage{
                      skill_id: 5,
                      level: 0,
                      damage: 0,
                      div: 1,
                      src_id: 1001,
                      target_id: 1001
                    }}

    assert Dsl.skilleffect(ctx, 18, 0).game_state == state.game_state
    assert_receive {:visual, %GroundSkill{skill_id: 18, level: 0, src_id: 1001, x: 150, y: 150}}
  end

  test "an inline item visual stands the player through the owning session state", %{state: state} do
    state = %{state | game_state: %{state.game_state | action_state: :sitting}}
    ctx = Ctx.from_session(state, {:item, 12414})
    result = Dsl.skilleffect(ctx, 29, 0)
    assert result.game_state.action_state == :idle
    assert Map.fetch!(result, :session_state).game_state.action_state == :idle
    assert_receive {:visual, %SkillEffect{skill_id: 29, level: 0}}

    stub(Interpreter, :can_stand?, fn _ -> false end)
    assert Dsl.skilleffect(ctx, 29, 0).game_state.action_state == :sitting
    assert_receive {:visual, %SkillEffect{skill_id: 29}}
  end

  test "inline deletion observes earlier script state and never calls the session", %{
    state: state
  } do
    Mimic.copy(InventoryOps)
    water = %InventoryItem{id: 7, nameid: 523, identify: 1, amount: 2}
    state = %{state | game_state: %{state.game_state | inventory: %{0 => water}}}

    stub(InventoryOps, :remove, fn 1001, inventory, index, amount ->
      Inventory.remove(inventory, index, amount)
    end)

    ctx = Ctx.from_session(state, {:item, 12217})
    ctx = Dsl.delitem(ctx, 523, 1)
    assert Dsl.count_item(ctx, 523) == 1
    assert Map.fetch!(ctx, :session_state).game_state.inventory[0].amount == 1
    assert {:script_end, ended} = catch_throw(Dsl.delitem(ctx, 523, 2))
    assert ended.status == {:error, :not_enough_items}
    assert Dsl.count_item(ended, 523) == 1
  end

  test "sitting restrictions reject before effects or consumption, with group override", %{
    state: state
  } do
    Mimic.copy(InventoryOps)

    item = %ItemDefinition{
      id: 12215,
      aegis_name: "Scroll",
      name: "Scroll",
      type: :usable,
      on_use: "ctx",
      no_use_sitting: true,
      use_override: 80
    }

    stub(Items, :by_id, fn 12215 -> {:ok, item} end)
    stub(Auth, :get_account!, fn 1001 -> %Account{gm_level: 79} end)
    stub(StatusManager, :recalculate_after_status_change, fn state -> state end)

    state = %{
      state
      | game_state: %{
          state.game_state
          | action_state: :sitting,
            inventory: %{0 => %InventoryItem{id: 1, nameid: 12215, amount: 2}}
        }
    }

    assert {:noreply, ^state} = ItemHandler.handle_use_item(2, state)
    assert_receive {:send, _, {:item_use_result, %ItemUseResult{ok: false}}}

    ScriptCompiler.compile_all!([item])
    stub(Auth, :get_account!, fn 1001 -> %Account{gm_level: 80} end)

    stub(InventoryOps, :remove, fn 1001, inventory, index, amount ->
      Inventory.remove(inventory, index, amount)
    end)

    assert {:noreply, used} = ItemHandler.handle_use_item(2, state)
    assert used.game_state.inventory[0].amount == 1
    assert_receive {:send, _, {:item_use_result, %ItemUseResult{ok: true}}}
  end
end
