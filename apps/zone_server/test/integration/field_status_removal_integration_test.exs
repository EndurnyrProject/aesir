defmodule Aesir.ZoneServer.Integration.FieldStatusRemovalIntegrationTest do
  @moduledoc """
  Real-session coverage for a field's leave events when a unit is removed from
  play without stepping off: a player warping off a Volcano loses its status
  and a mob despawning inside one loses it too (the source's `unit_remove_map`
  running `skill_unit_move` flag 4).
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Aesir.ZoneServer.HwProfessorFixture

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @swordman 1
  @sage 16
  @volcano 285
  @yellow_gemstone 715
  @blue_gemstone 717

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)

    sage =
      start_caster(@sage, %{"#{@volcano}" => 1}, [{@yellow_gemstone, 1}, {@blue_gemstone, 1}])

    %{sage: sage}
  end

  test "a player warping off a Volcano loses its status", %{sage: sage} do
    walker = start_caster(@swordman, %{}, [], %{last_x: 152})
    erupt(sage)
    walker_id = walker.character.id
    assert eventually(fn -> StatusStorage.has_status?(:player, walker_id, :sc_volcano) end)

    PlayerSession.warp(walker.pid, map(), 100, 100)

    assert eventually(fn -> get_player_state(walker.pid).x == 100 end)
    refute StatusStorage.has_status?(:player, walker_id, :sc_volcano)
    assert StatusStorage.has_status?(:player, sage.character.id, :sc_volcano)
  end

  test "a mob despawning inside a Volcano loses its status", %{sage: sage} do
    beast = start_target({153, 150})
    erupt(sage)
    assert eventually(fn -> StatusStorage.has_status?(:mob, beast.unit_id, :sc_volcano) end)

    :ok = GenServer.stop(beast.pid, :normal)

    refute StatusStorage.has_status?(:mob, beast.unit_id, :sc_volcano)
  end

  defp erupt(sage) do
    cast_ground(sage, @volcano, 1, {150, 150})
    sage_id = sage.character.id

    assert eventually(
             fn -> match?([_], Storage.get_groups_by_caster(:player, sage_id)) end,
             6_000
           )
  end
end
