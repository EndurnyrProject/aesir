defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtDetectingTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtDetecting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(Manager)
    Mimic.copy(SpatialIndex)
    Mimic.copy(UnitRegistry)
    Mimic.copy(Helpers)
    :ok
  end

  test "catalogs Detecting as an active ground utility with canonical data" do
    assert {:ok, definition} = Catalog.by_id(130)
    assert definition.name == :ht_detecting
    assert definition.display_name == "Detecting"
    assert definition.max_level == 4
    assert definition.target_type == :ground
    assert definition.damage_type == :no_damage
    assert definition.range == [3, 5, 7, 9]
    assert definition.sp_cost == [8, 8, 8, 8]
    assert definition.cast_time == []
    assert definition.after_cast_delay == []
    assert definition.splash_radius == 3
    assert {:ok, HtDetecting} = Catalog.active_module_for(:ht_detecting)
  end

  test "requires an equipped Falcon during active skill validation" do
    definition = HtDetecting.definition()

    assert {:error, :falcon_required} =
             HtDetecting.validate(%PlayerState{option: 0}, {:ground, 100, 100}, 1, definition)

    assert :ok =
             HtDetecting.validate(
               %PlayerState{option: Option.id(:falcon)},
               {:ground, 100, 100},
               1,
               definition
             )
  end

  test "reveals only living combat units and hidden traps in the target area" do
    caster = %PlayerState{character_id: 1000, map_name: "prontera", option: Option.id(:falcon)}

    living = %PlayerState{
      character_id: 2000,
      action_state: :idle,
      stats: %{current_state: %{hp: 1}}
    }

    dead = struct(MobState, %{instance_id: 3000, hp: 0, is_dead: true})
    definition = HtDetecting.definition()

    expect(Manager, :reveal_traps, fn "prontera", 150, 150, 3 -> {:ok, [10]} end)

    expect(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 6 ->
      [
        {:player, 2000},
        {:mob, 3000},
        {:skill_unit, 4000},
        {:player, 5000},
        {:player, 6000}
      ]
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :player, 2000 -> {:ok, {153, 153, "prontera"}}
      :mob, 3000 -> {:ok, {150, 150, "prontera"}}
      :player, 5000 -> {:ok, {154, 150, "prontera"}}
      :player, 6000 -> {:ok, {150, 150, "geffen"}}
    end)

    stub(UnitRegistry, :get_unit, fn
      :player, 2000 -> {:ok, {PlayerState, living, self()}}
      :mob, 3000 -> {:ok, {MobState, dead, self()}}
    end)

    expect(Helpers, :remove_statuses, fn {:player, 2000}, [:sc_hiding, :sc_cloaking] -> :ok end)

    assert {:ok, ^caster} = HtDetecting.cast(caster, {:ground, 150, 150}, 1, definition)
  end
end
