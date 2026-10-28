defmodule Aesir.ZoneServer.Mmo.Skills.Stalker.StChasewalkTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skills.Stalker.StChasewalk
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @tag game_mode: :pre_renewal
  test "classic: ending Chase Walk has no cast, starting it keeps its cast time" do
    player = player(1)

    assert StChasewalk.dynamic_cast_time(player, :self, 3, StChasewalk.definition()) ==
             %{cast_time: 1_200, fixed_cast_time: 0}

    :ok = StatusStorage.apply_status(:player, 1, :sc_chasewalk, val1: 3)

    assert StChasewalk.dynamic_cast_time(player, :self, 3, StChasewalk.definition()) ==
             %{cast_time: -1, fixed_cast_time: 0}
  end

  @tag game_mode: :renewal
  test "renewal: ending Chase Walk keeps its cast time" do
    player = player(2)
    :ok = StatusStorage.apply_status(:player, 2, :sc_chasewalk, val1: 3)

    assert StChasewalk.dynamic_cast_time(player, :self, 3, StChasewalk.definition()) ==
             %{cast_time: 500, fixed_cast_time: 500}
  end

  test "a cast starts Chase Walk at the cast level and a recast ends it" do
    player = player(3)

    assert {:ok, ^player} = StChasewalk.cast(player, :self, 4, StChasewalk.definition())
    assert %{val1: 4, val4: 18} = StatusStorage.get_status(:player, 3, :sc_chasewalk)

    assert {:ok, ^player} = StChasewalk.cast(player, :self, 4, StChasewalk.definition())
    refute StatusStorage.has_status?(:player, 3, :sc_chasewalk)
  end

  defp player(id) do
    player =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Stalker #{id}",
        last_map: "prontera",
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

    :ok = UnitRegistry.register_player(player, self())
    SpatialIndex.add_player(id, 50, 50, "prontera")
    player
  end
end
