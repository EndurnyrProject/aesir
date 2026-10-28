defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ChaseWalkTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "a paid drain keeps it and grants the STR buff once, which it does not renew" do
    pid = start_payer(1_000)
    register_player(1, "prontera", pid)
    :ok = Interpreter.apply_status(:player, 1, :sc_chasewalk, val1: 3)

    assert :continue = tick(1)
    assert_receive {:sp_paid, 16}
    assert StatusStorage.has_status?(:player, 1, :sc_chasewalk)
    assert %{val1: 4} = buff = StatusStorage.get_status(:player, 1, :sc_chasewalk2)
    assert Interpreter.get_all_modifiers(:player, 1) == %{movement_speed: 20, str: 4}

    assert :continue = tick(1)
    assert_receive {:sp_paid, 16}
    assert StatusStorage.get_status(:player, 1, :sc_chasewalk2) == buff
  end

  test "it lasts while its drains are paid, but ends on death" do
    register_player(8, "prontera", self())
    :ok = Interpreter.apply_status(:player, 8, :sc_chasewalk, val1: 1)
    assert %{expires_at: nil} = StatusStorage.get_status(:player, 8, :sc_chasewalk)

    :ok = Interpreter.remove_on_death(:player, 8)
    refute StatusStorage.has_status?(:player, 8, :sc_chasewalk)
  end

  test "a drain the holder cannot pay ends it without the STR buff" do
    register_player(2, "prontera", start_payer(0))
    :ok = Interpreter.apply_status(:player, 2, :sc_chasewalk, val1: 5)

    assert :stop = tick(2)
    refute StatusStorage.has_status?(:player, 2, :sc_chasewalk)
    refute StatusStorage.has_status?(:player, 2, :sc_chasewalk2)
  end

  test "the drain costs five times as much when it starts on a GvG or battleground map" do
    MapFlags.set_runtime("chase_gvg", :gvg_castle, true)
    MapFlags.set_runtime("chase_bg", :battleground, true)

    for {id, map, cost} <- [{3, "prontera", 14}, {4, "chase_gvg", 70}, {5, "chase_bg", 70}] do
      register_player(id, map, self())
      :ok = Interpreter.apply_status(:player, id, :sc_chasewalk, val1: 2)
      assert %{val4: ^cost} = StatusStorage.get_status(:player, id, :sc_chasewalk)
    end
  end

  test "the holder is cloaked and cannot attack or pick up items" do
    register_player(6, "prontera", self())
    :ok = Interpreter.apply_status(:player, 6, :sc_chasewalk, val1: 1)

    assert %{effect_state: 16_388} = StatusDisplay.spawn_state(:player, 6)
    refute Interpreter.can_attack?(:player, 6)
    assert Interpreter.has_active_flag?(:player, 6, :no_pick_item)
  end

  test "a monster holder pays no SP: every drain keeps it and grants the STR buff" do
    :ok = StatusStorage.apply_status(:mob, 7, :sc_chasewalk, val1: 5, val4: 20, tick: 10_000)
    register_mob(7)

    assert :continue =
             Interpreter.process_tick_if_current(:mob, 7, :sc_chasewalk, generation(:mob, 7))

    assert StatusStorage.has_status?(:mob, 7, :sc_chasewalk)
    assert %{val1: 16} = StatusStorage.get_status(:mob, 7, :sc_chasewalk2)
  end

  defp register_mob(id) do
    mob =
      %MobState{
        instance_id: id,
        mob_id: 1_002,
        mob_data: Aesir.TestMob.definition(),
        spawn_ref: nil,
        map_name: "prontera",
        x: 50,
        y: 50,
        hp: 100,
        sp: 0,
        spawned_at: 0
      }
      |> Aesir.TestMob.publish(max_hp: 100, max_sp: 0)

    :ok = UnitRegistry.register_unit(:mob, id, MobState, mob, self())
  end

  defp tick(id),
    do: Interpreter.process_tick_if_current(:player, id, :sc_chasewalk, generation(:player, id))

  defp generation(type, id), do: StatusStorage.get_status(type, id, :sc_chasewalk).generation

  defp register_player(id, map, pid) do
    player =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Stalker #{id}",
        last_map: map,
        last_x: 50,
        last_y: 50,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 99,
        job_level: 50,
        class: 4018
      })

    :ok = UnitRegistry.register_player(player, pid)
    SpatialIndex.add_player(id, 50, 50, map)
    player
  end

  defp start_payer(sp) do
    test_pid = self()
    spawn(fn -> payer_loop(sp, test_pid) end)
  end

  defp payer_loop(sp, test_pid) do
    receive do
      {:"$gen_call", from, {:unit, {:try_consume_sp, cost}}} when sp >= cost ->
        send(test_pid, {:sp_paid, cost})
        GenServer.reply(from, :ok)
        payer_loop(sp - cost, test_pid)

      {:"$gen_call", from, {:unit, {:try_consume_sp, _cost}}} ->
        GenServer.reply(from, {:error, :insufficient_sp})
        payer_loop(sp, test_pid)
    end
  end
end
