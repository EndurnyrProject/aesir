defmodule Aesir.ZoneServer.Mmo.Woe.FleeContextTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Unit.Player.CombatCalculations
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @castle_map "aldeg_cas01"

  setup :setup_ets_tables

  setup do
    :ok = MapFlags.reload()
    :ok
  end

  test "active GvG reduces pre-status flee by 20 percent" do
    stats = stats_with_base_flee_200(20)

    :ok = MapFlags.set_runtime(@castle_map, :gvg, true)

    assert CombatCalculations.calculate_flee(stats, @castle_map) == 180
  end

  test "the explicit stats map context reaches combat calculation" do
    stats = Stats.from_character(character())
    :ok = MapFlags.set_runtime(@castle_map, :gvg, true)

    baseline = Stats.calculate_stats(stats, nil, nil, nil).combat_stats.flee
    active = Stats.calculate_stats(stats, nil, nil, @castle_map).combat_stats.flee

    assert active == baseline - div(baseline * 20, 100)
  end

  test "an effective GvG transition notifies registered players including pending map loads" do
    game_state = %{PlayerState.new(character()) | map_name: @castle_map, pending_map_load: :warp}
    :ok = UnitRegistry.register_player(game_state, self())

    :ok = MapFlags.set_runtime(@castle_map, :gvg, true)

    assert_receive {:"$gen_cast", {:stats, :recalculate}}
  end

  defp stats_with_base_flee_200(status_flee) do
    {agi, luk, base_level} =
      case GameMode.mode() do
        :renewal -> {75, 0, 25}
        :pre_renewal -> {100, 0, 100}
      end

    %Stats{
      base_stats: %BaseStats{agi: agi, luk: luk},
      progression: %PlayerProgression{base_level: base_level, learned_skills: %{}},
      modifiers: %Modifiers{status_effects: %{flee: status_flee}}
    }
  end

  defp character do
    %Character{
      id: 8_001,
      account_id: 8_002,
      name: "FleeContext",
      class: 0,
      base_level: 50,
      job_level: 50,
      str: 10,
      agi: 80,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 30,
      hp: 100,
      sp: 50,
      last_map: "prontera",
      last_x: 150,
      last_y: 150
    }
  end
end

defmodule Aesir.ZoneServer.Mmo.Woe.FleeContextIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @castle_map "aldeg_cas01"

  setup do
    :ok = MapFlags.reload()
    :ok
  end

  test "warps apply destination flee before map-load acknowledgement and restore it on leave" do
    start_per_test_map(@castle_map)
    :ok = MapFlags.set_runtime(@castle_map, :gvg, true)

    session =
      start_player_session(
        id: 8_100,
        name: "FleeWarp",
        base_level: 50,
        job_level: 50,
        agi: 80,
        luk: 30
      )

    baseline = get_player_state(session.pid).stats.combat_stats.flee
    active = baseline - div(baseline * 20, 100)

    :ok = PlayerSession.warp(session.pid, @castle_map, 100, 100)

    assert_eventually(fn ->
      state = get_player_state(session.pid)

      state.map_name == @castle_map and state.pending_map_load == :warp and
        state.stats.combat_stats.flee == active
    end)

    simulate_incoming_message(session.pid, %MapLoaded{})
    assert_eventually(fn -> get_player_state(session.pid).pending_map_load == nil end)

    :ok = PlayerSession.warp(session.pid, "prontera", 150, 150)

    assert_eventually(fn ->
      state = get_player_state(session.pid)
      state.map_name == "prontera" and state.stats.combat_stats.flee == baseline
    end)
  end

  test "runtime GvG transitions refresh occupants without compounding flee" do
    start_per_test_map(@castle_map)

    session =
      start_player_session(
        id: 8_101,
        name: "FleeOccupant",
        map_name: @castle_map,
        base_level: 50,
        job_level: 50,
        agi: 80,
        luk: 30
      )

    baseline = get_player_state(session.pid).stats.combat_stats.flee
    active = baseline - div(baseline * 20, 100)

    :ok = MapFlags.set_runtime(@castle_map, :gvg, true)

    assert_eventually(fn -> get_player_state(session.pid).stats.combat_stats.flee == active end)
    assert_registry_flee(session.character.id, active)
    assert_flee_packet(active)

    :ok = PlayerSession.recalculate_stats(session.pid, false)
    :ok = PlayerSession.recalculate_stats(session.pid, false)

    assert_eventually(fn -> get_player_state(session.pid).stats.combat_stats.flee == active end)
    assert_registry_flee(session.character.id, active)

    :ok = MapFlags.clear_runtime(@castle_map, :gvg)

    assert_eventually(fn -> get_player_state(session.pid).stats.combat_stats.flee == baseline end)
    assert_registry_flee(session.character.id, baseline)
    assert_flee_packet(baseline)
  end

  defp assert_registry_flee(character_id, flee) do
    assert {:ok, {_module, game_state, _pid}} = UnitRegistry.get_unit(:player, character_id)
    assert game_state.stats.combat_stats.flee == flee
  end

  defp assert_flee_packet(flee) do
    assert_receive {:packet_sent, %ParamChange{var_id: var_id, value: ^flee}, :gameplay},
                   1_000

    assert var_id == StatusParams.flee1()
  end
end
