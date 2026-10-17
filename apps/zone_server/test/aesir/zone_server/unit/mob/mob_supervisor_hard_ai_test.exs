defmodule Aesir.ZoneServer.Unit.Mob.MobSupervisorHardAiTest do
  @moduledoc """
  Verifies the map's per-player hard AI pass: every mob within 18 cells of each
  player on the map gets one hard think from that player, a mob near two
  players two, a player on another map none.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobSupervisor
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "hard_ai_test"

  setup :setup_ets_tables
  setup :verify_on_exit!

  test "drives one hard think per player within the active range" do
    test_pid = self()

    stub(MobSession, :hard_think, fn pid, player_id ->
      send(test_pid, {:hard, pid, player_id})
      :ok
    end)

    SpatialIndex.add_player(1, 100, 100, @map)
    SpatialIndex.add_player(2, 110, 100, @map)
    SpatialIndex.add_player(3, 100, 100, "elsewhere")
    :ok = SpatialIndex.add_unit(:mob, 10, 105, 100, @map)
    :ok = SpatialIndex.add_unit(:mob, 11, 128, 100, @map)
    :ok = SpatialIndex.add_unit(:mob, 12, 150, 150, @map)
    near = spawn(fn -> Process.sleep(:infinity) end)
    far = spawn(fn -> Process.sleep(:infinity) end)
    UnitRegistry.register_unit(:mob, 10, nil, %{}, near)
    UnitRegistry.register_unit(:mob, 11, nil, %{}, far)
    UnitRegistry.register_unit(:mob, 12, nil, %{}, far)

    :ok = MobSupervisor.drive_hard_ai(@map, [1, 2, 3])

    assert_received {:hard, ^near, 1}
    assert_received {:hard, ^near, 2}
    assert_received {:hard, ^far, 2}
    refute_received {:hard, _pid, 3}
    refute_received {:hard, _pid, _player}
  end

  test "the active range is a square: a mob on its corner, 36 cells away by axes, thinks" do
    test_pid = self()

    stub(MobSession, :hard_think, fn pid, player_id ->
      send(test_pid, {:hard, pid, player_id})
      :ok
    end)

    SpatialIndex.add_player(1, 100, 100, @map)
    :ok = SpatialIndex.add_unit(:mob, 10, 118, 118, @map)
    :ok = SpatialIndex.add_unit(:mob, 11, 119, 118, @map)
    corner = spawn(fn -> Process.sleep(:infinity) end)
    outside = spawn(fn -> Process.sleep(:infinity) end)
    UnitRegistry.register_unit(:mob, 10, nil, %{}, corner)
    UnitRegistry.register_unit(:mob, 11, nil, %{}, outside)

    :ok = MobSupervisor.drive_hard_ai(@map, [1])

    assert_received {:hard, ^corner, 1}
    refute_received {:hard, ^outside, 1}
  end
end
