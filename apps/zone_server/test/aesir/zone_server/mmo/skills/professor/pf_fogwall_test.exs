defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfFogwallTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Professor.PfFogwall
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
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

  test "covers 5x3 cells for 20 s, or 40 s over a Deluge" do
    assert {:ok, placement} = PfFogwall.on_place(fog())

    assert Enum.sort(placement.cells) == for(x <- 48..52, y <- 49..51, do: {x, y})
    assert placement.duration == 20_000

    :ok = Storage.insert(group(9_401, :sa_deluge, [{52, 51}]))
    assert {:ok, %{duration: 40_000}} = PfFogwall.on_place(fog())
  end

  test "cannot be cast over Volcano or Violent Gale" do
    definition = PfFogwall.definition()
    assert PfFogwall.validate(@caster, {:ground, 50, 50}, 1, definition) == :ok

    :ok = Storage.insert(group(9_402, :sa_volcano, [{48, 49}]))

    assert PfFogwall.validate(@caster, {:ground, 50, 50}, 1, definition) ==
             {:error, :blocked_by_field}
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

  test "a player's Blind ends on leaving the fog; a monster's does not" do
    expect(StatusInterpreter, :remove_status, fn :player, 7, :sc_blind -> :ok end)
    assert {:ok, _group} = PfFogwall.on_out(fog(), {:player, 7})

    assert {:ok, _group} = PfFogwall.on_out(fog(), {:mob, 8})
  end
end
