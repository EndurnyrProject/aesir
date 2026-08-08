defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgCloseconfineTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgCloseconfine
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @caster_id 1_000
  @target_id 2_000

  setup do
    Catalog.reload()
    Registry.load_definitions()
    :ok
  end

  test "is discovered and roots both caster and mob target" do
    caster = register_player(@caster_id)
    register_mob(@target_id)

    assert {:ok, definition} = Catalog.by_id(1005)
    assert {:ok, RgCloseconfine} = Catalog.active_module_for(:rg_closeconfine)
    assert definition.display_name == "Close Confine"
    assert definition.max_level == 1
    assert definition.target_type == :target_enemy
    assert definition.range == 1
    assert %{icon: :rg_cconfine_m} = Registry.get_definition(:sc_closeconfine2)
    assert %{icon: :rg_cconfine_s} = Registry.get_definition(:sc_closeconfine)

    assert {:ok, ^caster} = RgCloseconfine.cast(caster, {:unit, @target_id}, 1, definition)

    assert %{val2: @target_id, expires_at: holder_expires, started_at: holder_started} =
             StatusStorage.get_status(:player, @caster_id, :sc_closeconfine2)

    assert %{val2: @caster_id, expires_at: victim_expires, started_at: victim_started} =
             StatusStorage.get_status(:mob, @target_id, :sc_closeconfine)

    assert holder_expires - holder_started == 10_000
    assert victim_expires - victim_started == 10_000
    refute StatusInterpreter.can_move?(:player, @caster_id)
    refute StatusInterpreter.can_move?(:mob, @target_id)
  end

  test "roots a player target" do
    caster = register_player(@caster_id)
    register_player(@target_id)

    assert {:ok, ^caster} =
             RgCloseconfine.cast(caster, {:unit, @target_id}, 1, skill_definition())

    assert %{val2: @target_id} =
             StatusStorage.get_status(:player, @caster_id, :sc_closeconfine2)

    assert %{val2: @caster_id} =
             StatusStorage.get_status(:player, @target_id, :sc_closeconfine)

    refute StatusInterpreter.can_move?(:player, @caster_id)
    refute StatusInterpreter.can_move?(:player, @target_id)
  end

  test "holder frees itself when its victim has died" do
    caster = register_player(@caster_id)
    target = register_mob(@target_id)
    definition = skill_definition()

    assert {:ok, ^caster} = RgCloseconfine.cast(caster, {:unit, @target_id}, 1, definition)
    :ok = UnitRegistry.update_unit_state(:mob, @target_id, %{target | hp: 0, is_dead: true})

    assert :ok = StatusInterpreter.process_tick(:player, @caster_id, :sc_closeconfine2)
    refute StatusStorage.has_status?(:player, @caster_id, :sc_closeconfine2)
    assert StatusInterpreter.can_move?(:player, @caster_id)
  end

  test "victim frees itself when its holder has left" do
    caster = register_player(@caster_id)
    register_mob(@target_id)
    definition = skill_definition()

    assert {:ok, ^caster} = RgCloseconfine.cast(caster, {:unit, @target_id}, 1, definition)
    :ok = UnitRegistry.unregister_unit(:player, @caster_id)

    assert :ok = StatusInterpreter.process_tick(:mob, @target_id, :sc_closeconfine)
    refute StatusStorage.has_status?(:mob, @target_id, :sc_closeconfine)
    assert StatusInterpreter.can_move?(:mob, @target_id)
  end

  defp skill_definition do
    {:ok, definition} = Catalog.by_name(:rg_closeconfine)
    definition
  end

  defp register_player(id) do
    character = %Character{
      id: id,
      account_id: id,
      name: "Rogue#{id}",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 90,
      job_level: 50,
      class: 23,
      party_id: 0
    }

    state = PlayerState.new(character)
    :ok = UnitRegistry.register_unit(:player, id, PlayerState, state, self())
    state
  end

  defp register_mob(id) do
    mob_data = %MobDefinition{
      id: 1004,
      aegis_name: "closeconfine_target",
      name: "Close Confine Target",
      level: 50,
      hp: 1000,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      matk: 0,
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300
    }

    spawn_ref = %MobSpawn{
      mob: 1004,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 50, y: 50}
    }

    state = MobState.new(id, mob_data, spawn_ref, "prontera", 50, 50)
    :ok = UnitRegistry.register_unit(:mob, id, MobState, state, self())
    state
  end
end
