defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AnkleSnareTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtAnklesnare
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.AnkleSnare
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    Code.ensure_loaded!(HtAnklesnare)
    player_id = :rand.uniform(100_000)
    :ok = UnitRegistry.register_player(player_state(player_id), self())

    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    %{manager: manager, player_id: player_id}
  end

  test "blocks movement and AL_TELEPORT only", %{player_id: player_id} do
    assert :ok = apply_status(player_id, 1, 7)

    refute Interpreter.can_move?(:player, player_id)
    assert Interpreter.can_attack?(:player, player_id)
    assert Interpreter.can_use_skill?(:player, player_id)
    refute Interpreter.can_use_skill?(:player, player_id, 26)
    assert Interpreter.can_use_skill?(:player, player_id, 28)

    assert AnkleSnare.metadata().no_save
    assert AnkleSnare.metadata().remove_on_map_change
    assert AnkleSnare.metadata().no_dispel
  end

  test "status-first teardown removes its matching group and duplicate cleanup is inert",
       context do
    insert_captured_group(context.player_id, 1, 7)
    assert :ok = apply_status(context.player_id, 1, 7)

    assert :ok = Interpreter.remove_status(:player, context.player_id, :sc_anklesnare)
    eventually(fn -> is_nil(Storage.get(1)) end)

    assert :ok = Interpreter.remove_status(:player, context.player_id, :sc_anklesnare)
    assert :ok = Manager.release_trap_link(context.manager, 1, 7)
    assert nil == Storage.get(1)
  end

  test "group-first teardown clears only its matching status back-reference", context do
    insert_captured_group(context.player_id, 1, 7)
    assert :ok = apply_status(context.player_id, 1, 7)
    assert function_exported?(HtAnklesnare, :on_expire, 1)

    assert %{state: %{group_id: 1, link_id: 7}} =
             StatusStorage.get_status(:player, context.player_id, :sc_anklesnare)

    assert :ok = Manager.release_trap_link(context.manager, 1, 7)

    eventually(fn ->
      is_nil(Storage.get(1)) and
        not StatusStorage.has_status?(:player, context.player_id, :sc_anklesnare)
    end)
  end

  test "death and warp cleanup each release the linked group", context do
    insert_captured_group(context.player_id, 1, 7)
    assert :ok = apply_status(context.player_id, 1, 7)
    assert :ok = Interpreter.remove_all_statuses(:player, context.player_id)
    eventually(fn -> is_nil(Storage.get(1)) end)

    insert_captured_group(context.player_id, 2, 8)
    assert :ok = apply_status(context.player_id, 2, 8)
    assert :ok = Interpreter.remove_on_map_change(:player, context.player_id)
    eventually(fn -> is_nil(Storage.get(2)) end)
  end

  test "stale group links remove the status without touching another group", context do
    insert_captured_group(context.player_id, 1, 8)
    assert :ok = apply_status(context.player_id, 1, 7)

    assert :ok = Interpreter.process_tick(:player, context.player_id, :sc_anklesnare)

    refute StatusStorage.has_status?(:player, context.player_id, :sc_anklesnare)
    assert %Group{state: %{trap: %TrapState{link_id: 8}}} = Storage.get(1)
  end

  defp apply_status(player_id, group_id, link_id) do
    Interpreter.apply_status(:player, player_id, :sc_anklesnare,
      duration: 10_000,
      state: %{group_id: group_id, link_id: link_id}
    )
  end

  defp insert_captured_group(player_id, group_id, link_id) do
    Storage.insert(%Group{
      group_id: group_id,
      skill_id: 117,
      skill_name: :ht_anklesnare,
      level: 1,
      caster_id: 500,
      caster_type: :player,
      target_id: player_id,
      target_type: :player,
      map_name: "prontera",
      center: {100, 100},
      cells: [{100, 100}],
      next_tick_at: nil,
      expires_at: System.monotonic_time(:millisecond) + 10_000,
      interval: 1_000,
      visible?: true,
      state: %{
        trap: %TrapState{phase: :captured, reclaim_item_id: 1065, link_id: link_id}
      },
      handler: HtAnklesnare
    })
  end

  defp player_state(player_id) do
    %Character{
      id: player_id,
      account_id: player_id,
      name: "AnkleSnareTest",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
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
    |> PlayerState.new()
  end

  defp eventually(fun, attempts \\ 20)
  defp eventually(fun, 0), do: assert(fun.())

  defp eventually(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(5)
      eventually(fun, attempts - 1)
    end
  end
end
