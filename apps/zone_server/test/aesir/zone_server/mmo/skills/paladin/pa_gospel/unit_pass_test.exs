defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.UnitPassTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Effects
  alias Aesir.ZoneServer.TrapTestHelper
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 49_101
  @mob_id 49_102
  @map "prontera"

  setup :setup_ets_tables
  setup {Aesir.MimicMode, :global}

  setup do
    Mimic.copy(Effects)
    test_pid = self()

    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)

    stub(Combat, :resolve_combatant, fn :player, @caster_id ->
      {:ok, %{unit_type: :player, unit_id: @caster_id, map_name: @map, party_id: 0}}
    end)

    stub(Effects, :afflict, fn group, _caster_state, target ->
      send(test_pid, {:afflict, group.group_id, target})
      :ok
    end)

    :ok = UnitRegistry.register_player(TrapTestHelper.player(@caster_id), self())
    :ok = UnitRegistry.register_unit(:mob, @mob_id, MobState, TrapTestHelper.mob(@mob_id), self())

    %{manager: manager}
  end

  test "two Gospels share one 10 s interval per unit", %{manager: manager} do
    :ok = Manager.register(manager, gospel(1, {50, 50}))
    :ok = Manager.register(manager, gospel(2, {60, 50}))
    :ok = SpatialIndex.add_unit(:mob, @mob_id, 50, 50, @map)

    :ok = Manager.tick(manager, 1_000)
    assert_received {:afflict, 1, {:mob, @mob_id}}

    :ok = SpatialIndex.update_unit_position(:mob, @mob_id, 60, 50, @map)
    :ok = Manager.tick(manager, 5_000)
    refute_received {:afflict, _, _}

    :ok = Manager.tick(manager, 11_000)
    assert_received {:afflict, 2, {:mob, @mob_id}}
  end

  defp gospel(group_id, center) do
    %Group{
      group_id: group_id,
      skill_id: 369,
      skill_name: :pa_gospel,
      level: 10,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map,
      center: center,
      cells: PaGospel.thick_cross(center),
      created_at: 0,
      next_tick_at: nil,
      expires_at: 60_000,
      interval: 10_000,
      unit_range: 0,
      no_overlap: true,
      handler: PaGospel,
      state: %{rng: fn 100 -> 1 end}
    }
  end
end
