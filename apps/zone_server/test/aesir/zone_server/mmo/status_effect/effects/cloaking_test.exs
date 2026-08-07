defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CloakingTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Cloaking
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "movement commands refresh open and adjacent speed branches while CRIT remains doubled" do
    player = register_player(1)
    cache(MapData.new("cloaking", 5, 5))
    apply_cloaking(player, 5, false)

    assert Interpreter.get_all_modifiers(:player, 1) == %{
             critical_rate: 100,
             movement_speed: 15
           }

    cache(MapData.new("cloaking", 5, 5) |> MapData.set_cell(2, 1, GatType.wall()))

    assert :changed =
             Interpreter.on_movement_intent(:player, 1, %{map: "cloaking", x: 2, y: 2})

    assert Interpreter.get_all_modifiers(:player, 1) == %{
             critical_rate: 100,
             movement_speed: -12
           }

    cache(MapData.new("cloaking", 5, 5))

    assert :changed =
             Interpreter.on_movement_intent(:player, 1, %{map: "cloaking", x: 2, y: 2})

    assert Interpreter.get_all_modifiers(:player, 1) == %{
             critical_rate: 100,
             movement_speed: 15
           }
  end

  test "modifiers/2 stays total for a level-less entry instead of crashing the recalc" do
    # A directly-applied sc_cloaking with no val1 (level 0) must not raise a
    # FunctionClauseError and take the unit's whole stat recalculation down.
    entry = %StatusEntry{type: :sc_cloaking, val1: 0, state: %{}}

    assert Cloaking.modifiers(entry, %{}) == %{critical_rate: 100, movement_speed: 0}
  end

  test "low levels end on the next open-terrain movement command but higher levels remain" do
    low = register_player(2)
    high = register_player(3)
    cache(MapData.new("cloaking", 5, 5))
    apply_cloaking(low, 2, true)
    apply_cloaking(high, 3, true)

    assert :changed =
             Interpreter.on_movement_intent(:player, 2, %{map: "cloaking", x: 2, y: 2})

    refute StatusStorage.has_status?(:player, 2, :sc_cloaking)

    assert :changed =
             Interpreter.on_movement_intent(:player, 3, %{map: "cloaking", x: 2, y: 2})

    assert %{state: %{adjacent_impassable?: false}} =
             StatusStorage.get_status(:player, 3, :sc_cloaking)
  end

  test "committed actions remove Cloaking except for its own toggle skill" do
    player = register_player(4)
    apply_cloaking(player, 5, false)

    assert :unchanged = Interpreter.on_committed_action(:player, 4, {:skill, 135})
    assert StatusStorage.has_status?(:player, 4, :sc_cloaking)

    assert :changed = Interpreter.on_committed_action(:player, 4, {:skill, 136})
    refute StatusStorage.has_status?(:player, 4, :sc_cloaking)

    apply_cloaking(player, 5, false)
    assert :changed = Interpreter.on_committed_action(:player, 4, :normal_attack)
    refute StatusStorage.has_status?(:player, 4, :sc_cloaking)
  end

  test "positive delivered damage removes Cloaking while a fully absorbed hit does not" do
    player = register_player(5)
    apply_cloaking(player, 5, false)

    assert 0 = Interpreter.after_damage_taken(:player, 5, %{damage: 0})
    assert StatusStorage.has_status?(:player, 5, :sc_cloaking)

    assert 0 = Interpreter.after_damage_taken(:player, 5, %{damage: 1})
    refute StatusStorage.has_status?(:player, 5, :sc_cloaking)
  end

  test "ticks pay one SP atomically, remove on failure, and ignore stale generations" do
    paying_pid = start_payer(1)
    paying = register_player(6, paying_pid)
    apply_cloaking(paying, 5, false)
    paying_entry = StatusStorage.get_status(:player, 6, :sc_cloaking)

    assert :continue =
             Interpreter.process_tick_if_current(
               :player,
               6,
               :sc_cloaking,
               paying_entry.generation
             )

    assert_receive {:sp_paid, ^paying_pid, 0}
    assert StatusStorage.has_status?(:player, 6, :sc_cloaking)

    empty_pid = start_payer(0)
    empty = register_player(7, empty_pid)
    apply_cloaking(empty, 5, false)
    empty_entry = StatusStorage.get_status(:player, 7, :sc_cloaking)

    assert :stop =
             Interpreter.process_tick_if_current(:player, 7, :sc_cloaking, empty_entry.generation)

    refute StatusStorage.has_status?(:player, 7, :sc_cloaking)

    stale_pid = start_payer(1)
    stale = register_player(8, stale_pid)
    apply_cloaking(stale, 5, false)
    stale_generation = StatusStorage.get_status(:player, 8, :sc_cloaking).generation
    apply_cloaking(stale, 6, false)
    current = StatusStorage.get_status(:player, 8, :sc_cloaking)

    assert :stop =
             Interpreter.process_tick_if_current(:player, 8, :sc_cloaking, stale_generation)

    assert StatusStorage.get_status(:player, 8, :sc_cloaking) == current
    refute_receive {:sp_paid, ^stale_pid, _balance}
  end

  test "a tick that loses its generation cannot remove the replacement" do
    payer_pid = start_replacing_payer(9)
    player = register_player(9, payer_pid)
    apply_cloaking(player, 5, false)

    assert :ok = Interpreter.process_tick(:player, 9, :sc_cloaking)
    assert %{val1: 6} = StatusStorage.get_status(:player, 9, :sc_cloaking)
  end

  test "keeps Cloaking's lifecycle and pickup metadata" do
    metadata = Cloaking.metadata()

    assert metadata.no_save
    assert metadata.no_dispel
    assert metadata.remove_on_map_change
    assert :conceals in metadata.properties
    assert :no_pick_item in metadata.flags
  end

  defp apply_cloaking(player, level, adjacent?) do
    Interpreter.apply_status(:player, player.character_id, :sc_cloaking,
      val1: level,
      tick: 1_000,
      caster_id: player.character_id,
      state: %{adjacent_impassable?: adjacent?}
    )
  end

  defp cache(map), do: :ets.insert(EtsTable.table_for(:map_cache), {map.name, map})

  defp register_player(id, pid \\ self()) do
    player =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Player #{id}",
        last_map: "cloaking",
        last_x: 2,
        last_y: 2,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 50,
        job_level: 50,
        class: 12
      })

    :ok = UnitRegistry.register_player(player, pid)
    player
  end

  defp start_payer(sp) do
    test_pid = self()
    spawn(fn -> payer_loop(sp, test_pid) end)
  end

  defp start_replacing_payer(player_id) do
    spawn(fn -> replacing_payer_loop(player_id) end)
  end

  defp replacing_payer_loop(player_id) do
    receive do
      {:"$gen_call", from, {:unit, {:try_consume_sp, 1}}} ->
        :ok =
          StatusStorage.apply_status(:player, player_id, :sc_cloaking,
            val1: 6,
            state: %{adjacent_impassable?: false}
          )

        GenServer.reply(from, {:error, :insufficient_sp})
        replacing_payer_loop(player_id)
    end
  end

  defp payer_loop(sp, test_pid) do
    receive do
      {:"$gen_call", from, {:unit, {:try_consume_sp, 1}}} when sp > 0 ->
        GenServer.reply(from, :ok)
        send(test_pid, {:sp_paid, self(), sp - 1})
        payer_loop(sp - 1, test_pid)

      {:"$gen_call", from, {:unit, {:try_consume_sp, 1}}} ->
        GenServer.reply(from, {:error, :insufficient_sp})
        payer_loop(sp, test_pid)
    end
  end
end
