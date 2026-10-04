defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfFogwallTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Professor.PfFogwall
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  @caster_id 9_301
  @caster %PlayerState{character_id: @caster_id, map_name: "prontera", x: 100, y: 100}

  defp group(group_id, skill_name, cells) do
    %Group{
      group_id: group_id,
      skill_id: 1,
      skill_name: skill_name,
      level: 1,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: "prontera",
      center: hd(cells),
      cells: cells,
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      state: %{}
    }
  end

  defp fog, do: group(9_400, :pf_fogwall, [{50, 50}])

  defp register_mover(:mob, id) do
    {:ok, definition} = Mobs.by_id(1002)

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %MobSpawn.SpawnArea{x: 50, y: 50, xs: 0, ys: 0}
    }

    mob = MobState.new(id, definition, spawn, "prontera", 50, 50)
    :ok = UnitRegistry.register_unit(:player, @caster_id, PlayerState, @caster, self())
    :ok = UnitRegistry.register_unit(:mob, id, MobState, mob, self())
  end

  test "covers 5x3 cells for 20 s and ticks nothing" do
    assert {:ok, placement} = PfFogwall.on_place(fog())

    assert Enum.sort(placement.cells) == for(x <- 48..52, y <- 49..51, do: {x, y})
    assert placement.duration == 20_000
    refute Map.has_key?(placement.state, :short_cells)
  end

  test "cells over Volcano or Violent Gale are dropped, the rest still placed" do
    :ok = Storage.insert(group(9_402, :sa_volcano, [{48, 49}]))
    :ok = Storage.insert(group(9_403, :sa_violentgale, [{52, 51}]))

    assert {:ok, placement} = PfFogwall.on_place(fog())

    assert length(placement.cells) == 13
    refute {48, 49} in placement.cells
    refute {52, 51} in placement.cells
  end

  test "cells over a Deluge last 40 s while the others end at 20 s" do
    :ok = Storage.insert(group(9_401, :sa_deluge, [{52, 51}]))

    assert {:ok, placement} = PfFogwall.on_place(fog())

    assert placement.duration == 40_000
    assert placement.interval == 20_000
    assert placement.initial_delay == 20_000
    assert length(placement.state.short_cells) == 14
    refute {52, 51} in placement.state.short_cells

    group = %{fog() | cells: placement.cells, state: placement.state}

    assert {:ok, %Group{state: state}, {:remove_cells, short}} = PfFogwall.on_interval(group, 0)
    assert short == placement.state.short_cells
    refute Map.has_key?(state, :short_cells)
  end

  test "every occupant holds the fog status" do
    assert %{status_type: :sc_fogwall, target?: target?} = PfFogwall.field_support(fog())
    assert target?.({:player, @caster_id})
    assert target?.({:mob, 1})
  end

  test "an entering enemy without Deluge is blinded for 10 s" do
    register_mover(:mob, 9_501)
    stub(Targeting, :validate_field_target, fn _group, _caster, _target -> :ok end)

    expect(StatusInterpreter, :apply_status, fn :mob, 9_501, :sc_blind, params ->
      assert params[:duration] == 10_000
      :ok
    end)

    assert {:ok, _group} = PfFogwall.on_touch(fog(), {:mob, 9_501})
  end

  test "allies and Deluge holders are not blinded" do
    register_mover(:mob, 9_501)
    reject(&StatusInterpreter.apply_status/4)

    stub(Targeting, :validate_field_target, fn _group, _caster, _target ->
      {:error, :invalid_target}
    end)

    assert {:ok, _group} = PfFogwall.on_touch(fog(), {:mob, 9_501})

    stub(Targeting, :validate_field_target, fn _group, _caster, _target -> :ok end)
    :ok = StatusStorage.apply_status(:mob, 9_501, :sc_deluge, val1: 1)
    assert {:ok, _group} = PfFogwall.on_touch(fog(), {:mob, 9_501})
  end

  test "a unit already standing in fog is not blinded again" do
    register_mover(:mob, 9_501)
    stub(Targeting, :validate_field_target, fn _group, _caster, _target -> :ok end)
    :ok = StatusStorage.apply_status(:mob, 9_501, :sc_fogwall)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, _group} = PfFogwall.on_touch(fog(), {:mob, 9_501})
  end

  test "casting blinds enemies already standing in the fog" do
    register_mover(:mob, 9_501)
    stub(Targeting, :validate_field_target, fn _group, _caster, _target -> :ok end)
    :ok = SpatialIndex.add_unit(:mob, 9_501, 50, 50, "prontera")
    placed = %{fog() | cells: for(x <- 48..52, y <- 49..51, do: {x, y})}
    stub(Unit, :place, fn @caster, :pf_fogwall, 1, {50, 50} -> {:ok, placed} end)

    expect(StatusInterpreter, :apply_status, fn :mob, 9_501, :sc_blind, params ->
      assert params[:duration] == 10_000
      :ok
    end)

    assert {:ok, @caster} = PfFogwall.cast(@caster, {:ground, 50, 50}, 1, PfFogwall.definition())
  end

  test "a fog blocked on every cell still spends the cast" do
    stub(Unit, :place, fn @caster, :pf_fogwall, 1, {50, 50} -> {:error, :no_walkable_cells} end)

    assert {:ok, @caster} = PfFogwall.cast(@caster, {:ground, 50, 50}, 1, PfFogwall.definition())
  end
end
