defmodule Aesir.ZoneServer.Mmo.Skills.WzEarthspikeTest do
  use ExUnit.Case, async: false
  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.WzEarthspike
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!
  setup :setup_ets_tables

  @mob_id 2000

  defp caster, do: %PlayerState{character_id: 1000}

  defp interpreter_caster do
    %{
      character_id: 1000,
      party_id: 0,
      guild_id: 0,
      x: 10,
      y: 10,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{sp: 100, hp: 100},
        derived_stats: %{max_sp: 100, max_hp: 100},
        progression: %{learned_skills: %{90 => 5}},
        equipment: %Equipment{}
      }
    }
  end

  describe "definition/0" do
    test "matches the rAthena Renewal table" do
      definition = WzEarthspike.definition()

      assert definition.id == 90
      assert definition.name == :wz_earthspike
      assert definition.display_name == "Earth Spike"
      assert definition.max_level == 5
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :damage
      assert definition.damage_kind == :magic
      assert definition.element == :earth
      assert definition.range == 9
      assert definition.sp_cost == [14, 18, 22, 26, 30]
      assert definition.cast_time == [800, 1400, 2000, 2600, 3200]
      assert definition.fixed_cast_time == [400, 600, 800, 1000, 1200]
      assert definition.after_cast_delay == List.duplicate(1400, 5)
      assert definition.cooldown == []
    end
  end

  describe "cast/4" do
    test "level 1 resolves one 200% Earth hit against a mob target" do
      caster = caster()
      definition = WzEarthspike.definition()

      expect(Combat, :execute_magic_attack, fn ^caster, @mob_id, opts ->
        assert opts[:skill_id] == 90
        assert opts[:skill_level] == 1
        assert opts[:skill_ratio] == 200
        assert opts[:hit_count] == 1
        assert opts[:element] == :earth
        :ok
      end)

      assert {:ok, ^caster} =
               WzEarthspike.cast(caster, {:unit, @mob_id}, 1, definition)
    end

    test "level 5 passes five 200% Earth hits to the magic pipeline" do
      caster = caster()
      definition = WzEarthspike.definition()

      expect(Combat, :execute_magic_attack, fn ^caster, @mob_id, opts ->
        assert opts[:skill_id] == 90
        assert opts[:skill_level] == 5
        assert opts[:skill_ratio] == 200
        assert opts[:hit_count] == 5
        assert opts[:element] == :earth
        :ok
      end)

      assert {:ok, ^caster} =
               WzEarthspike.cast(caster, {:unit, @mob_id}, 5, definition)
    end

    test "Earth Care option raises each hit from 200% to 1800% MATK" do
      caster = caster()
      definition = WzEarthspike.definition()
      :ok = StatusStorage.apply_status(:player, caster.character_id, :sc_earth_care_option)

      expect(Combat, :execute_magic_attack, fn ^caster, @mob_id, opts ->
        assert opts[:skill_ratio] == 1800
        :ok
      end)

      assert {:ok, ^caster} =
               WzEarthspike.cast(caster, {:unit, @mob_id}, 3, definition)
    end

    for {label, reason} <- [invalid: :target_not_found, dead: :target_dead] do
      test "propagates #{label} target rejection" do
        caster = caster()
        definition = WzEarthspike.definition()

        expect(Combat, :execute_magic_attack, fn ^caster, @mob_id, _opts ->
          {:error, unquote(reason)}
        end)

        assert {:error, unquote(reason)} =
                 WzEarthspike.cast(caster, {:unit, @mob_id}, 3, definition)
      end
    end
  end

  describe "Skill.Interpreter target_enemy path" do
    test "rejects Earth Spike on another player" do
      caster = interpreter_caster()

      stub(Catalog, :by_id, fn 90 -> {:ok, WzEarthspike.definition()} end)
      stub(Catalog, :active_module_for, fn :wz_earthspike -> {:ok, WzEarthspike} end)

      stub(SpatialIndex, :get_unit_position, fn
        :mob, 2000 -> {:error, :not_found}
        :player, 2000 -> {:ok, {12, 10, "prontera"}}
      end)

      assert {:error, :invalid_target} = Interpreter.cast(caster, 90, 5, {:unit, 2000})
    end
  end
end
