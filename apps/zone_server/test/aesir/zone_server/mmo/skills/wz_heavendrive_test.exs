defmodule Aesir.ZoneServer.Mmo.Skills.WzHeavendriveTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skills.WzHeavendrive
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  defmodule FakeUnit do
    @moduledoc false
    defstruct [
      :combatant,
      :stats,
      :x,
      :y,
      :map_name,
      :hp,
      :action_state,
      :character_id,
      :party_id,
      :guild_id
    ]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
  end

  defp combatant(unit_id, unit_type, x, y) do
    Combatant.new!(%{
      unit_id: unit_id,
      unit_type: unit_type,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{
        atk: 0,
        def: 0,
        hit: 200,
        flee: 0,
        perfect_dodge: 0,
        matk: 100,
        matk_min: 100,
        matk_max: 100,
        mdef: 0,
        soft_mdef: 0
      },
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 5,
      attack_delay_ms: 500,
      position: {x, y},
      map_name: "prontera"
    })
  end

  defp fake_unit(unit_id, unit_type, x, y, opts \\ []) do
    party_id = Keyword.get(opts, :party_id, 0)
    guild_id = Keyword.get(opts, :guild_id, 0)

    %FakeUnit{
      combatant: %{
        combatant(unit_id, unit_type, x, y)
        | party_id: party_id,
          guild_id: guild_id
      },
      stats: %{},
      x: x,
      y: y,
      map_name: "prontera",
      hp: 100,
      action_state: :idle,
      character_id: unit_id,
      party_id: party_id,
      guild_id: guild_id
    }
  end

  defp interpreter_state do
    %{
      character_id: 1_000,
      x: 10,
      y: 10,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      stats: %{
        progression: %{learned_skills: %{91 => 1}},
        current_state: %{sp: 100, hp: 100},
        derived_stats: %{max_sp: 100, max_hp: 100},
        base_stats: %{dex: 1, int: 1}
      }
    }
  end

  describe "definition/0" do
    test "matches the Renewal Heaven's Drive table" do
      definition = WzHeavendrive.definition()

      assert definition.id == 91
      assert definition.name == :wz_heavendrive
      assert definition.max_level == 5
      assert definition.target_type == :ground
      assert definition.damage_type == :damage
      assert definition.damage_kind == :magic
      assert definition.range == 9
      assert definition.element == :earth
      assert definition.splash_radius == 2
      assert definition.cast_time == [1_100, 1_300, 1_500, 1_700, 1_900]
      assert definition.fixed_cast_time == List.duplicate(800, 5)
      assert definition.after_cast_delay == List.duplicate(500, 5)
      assert definition.cooldown == List.duplicate(1_000, 5)
      assert definition.sp_cost == [28, 32, 36, 40, 44]
    end

    test "radius 2 includes the 5x5 corners and excludes the next cell" do
      radius = WzHeavendrive.definition().splash_radius
      cells = Layout.square({150, 150}, radius)

      assert length(cells) == 25
      assert {148, 148} in cells
      assert {152, 152} in cells
      refute {147, 150} in cells
      refute {150, 153} in cells
    end

    test "is active without a persistent ground-unit capability" do
      assert WzHeavendrive.__skill_capabilities__() == [:active]
      refute function_exported?(WzHeavendrive, :on_place, 1)
    end
  end

  describe "cast/4" do
    test "level 1 immediately hits the 5x5 footprint once at 125% Earth MATK" do
      caster = %{character_id: 1_000}
      definition = WzHeavendrive.definition()

      expect(Combat, :execute_magic_splash, fn ^caster, {150, 150}, 2, opts ->
        assert opts[:skill_id] == 91
        assert opts[:skill_level] == 1
        assert opts[:skill_ratio] == 125
        assert opts[:element] == :earth
        assert opts[:split] == false
        [{:mob, 2_001}]
      end)

      assert {:ok, ^caster} =
               WzHeavendrive.cast(caster, {:ground, 150, 150}, 1, definition)
    end

    test "level 5 hits every target in the footprint five times" do
      caster = %{character_id: 1_000}
      definition = WzHeavendrive.definition()

      expect(Combat, :execute_magic_splash, 5, fn ^caster, {150, 150}, 2, opts ->
        assert opts[:skill_level] == 5
        [{:mob, 2_001}, {:mob, 2_002}]
      end)

      expect(StatusInterpreter, :remove_status, 10, fn :mob, target_id, :sc_sv_roottwist ->
        assert target_id in [2_001, 2_002]
        :ok
      end)

      assert {:ok, ^caster} =
               WzHeavendrive.cast(caster, {:ground, 150, 150}, 5, definition)
    end

    test "an empty target cell still completes the cast" do
      caster = %{character_id: 1_000}
      definition = WzHeavendrive.definition()

      expect(Combat, :execute_magic_splash, fn ^caster, {90, 120}, 2, _opts -> [] end)

      assert {:ok, ^caster} =
               WzHeavendrive.cast(caster, {:ground, 90, 120}, 1, definition)
    end

    test "removes Silvervine Root Twist from every mob and player hit" do
      caster = %{character_id: 1_000}
      definition = WzHeavendrive.definition()

      stub(Combat, :execute_magic_splash, fn _, _, _, _ ->
        [{:mob, 2_001}, {:player, 3_001}]
      end)

      expect(StatusInterpreter, :remove_status, fn :mob, 2_001, :sc_sv_roottwist -> :ok end)
      expect(StatusInterpreter, :remove_status, fn :player, 3_001, :sc_sv_roottwist -> :ok end)

      assert {:ok, ^caster} =
               WzHeavendrive.cast(caster, {:ground, 150, 150}, 1, definition)
    end

    test "excludes a hostile player from the splash until PvP exists" do
      caster = fake_unit(1_000, :player, 150, 150)
      target_id = 3_001
      target = fake_unit(target_id, :player, 149, 150)
      registered_mob = fake_unit(target_id, :mob, 151, 150)
      player_pid = spawn(fn -> Process.sleep(:infinity) end)
      mob_pid = spawn(fn -> Process.sleep(:infinity) end)

      on_exit(fn ->
        Process.exit(player_pid, :kill)
        Process.exit(mob_pid, :kill)
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 4 ->
        [{:player, target_id}]
      end)

      stub(UnitRegistry, :get_unit, fn :mob, ^target_id ->
        {:ok, {FakeUnit, registered_mob, mob_pid}}
      end)

      stub(UnitRegistry, :get_player_pid, fn ^target_id -> {:ok, player_pid} end)
      stub(PlayerSession, :get_current_stats, fn ^player_pid -> target.stats end)
      stub(PlayerSession, :get_state, fn ^player_pid -> %{game_state: target} end)

      reject(&MagicDamageCalculator.calculate_magic_damage/3)
      reject(&PlayerSession.apply_damage/3)
      reject(&MobSession.apply_damage/3)
      reject(&StatusInterpreter.remove_status/3)

      assert {:ok, ^caster} =
               WzHeavendrive.cast(
                 caster,
                 {:ground, 150, 150},
                 1,
                 WzHeavendrive.definition()
               )
    end

    @tag :relation_dependency
    test "production path hits inner and edge mob targets only, excluding players" do
      caster = fake_unit(1_000, :player, 150, 150, party_id: 7, guild_id: 9)

      units = %{
        2_001 => fake_unit(2_001, :mob, 150, 150),
        2_002 => fake_unit(2_002, :mob, 152, 152),
        2_003 => fake_unit(2_003, :mob, 153, 150),
        3_001 => fake_unit(3_001, :player, 149, 149),
        3_002 => fake_unit(3_002, :player, 151, 150, party_id: 7),
        3_003 => fake_unit(3_003, :player, 150, 151, guild_id: 9),
        1_000 => caster
      }

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 4 ->
        [
          {:mob, 2_001},
          {:mob, 2_002},
          {:mob, 2_003},
          {:player, 3_001},
          {:player, 3_002},
          {:player, 3_003},
          {:player, 1_000}
        ]
      end)

      stub(UnitRegistry, :get_unit, fn :mob, unit_id ->
        case Map.fetch(units, unit_id) do
          {:ok, %FakeUnit{combatant: %{unit_type: :mob}} = unit} ->
            {:ok, {FakeUnit, unit, self()}}

          _ ->
            {:error, :not_found}
        end
      end)

      stub(SpatialIndex, :get_unit_position, fn unit_type, unit_id ->
        case Map.fetch(units, unit_id) do
          {:ok, %FakeUnit{combatant: %{unit_type: ^unit_type}, x: x, y: y}} ->
            {:ok, {x, y, "prontera"}}

          _ ->
            {:error, :not_found}
        end
      end)

      player_pids =
        Map.new([1_000, 3_001, 3_002, 3_003], &{&1, spawn(fn -> Process.sleep(:infinity) end)})

      stub(UnitRegistry, :get_player_pid, fn unit_id ->
        case Map.fetch(player_pids, unit_id) do
          {:ok, pid} -> {:ok, pid}
          :error -> {:error, :not_found}
        end
      end)

      stub(PlayerSession, :get_current_stats, fn pid ->
        {unit_id, ^pid} =
          Enum.find(player_pids, fn {_unit_id, player_pid} -> player_pid == pid end)

        units[unit_id].stats
      end)

      stub(PlayerSession, :get_state, fn pid ->
        {unit_id, ^pid} =
          Enum.find(player_pids, fn {_unit_id, player_pid} -> player_pid == pid end)

        %{game_state: units[unit_id]}
      end)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _attacker, _target, opts ->
        assert opts[:element] == :earth
        assert opts[:skill_ratio] == 125
        {:ok, %{damage: 40, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      stub(StatusInterpreter, :absorb_damage, fn _type, _id, damage, _hit_info -> damage end)

      expect(MobSession, :apply_damage, 2, fn _pid, 40, 1_000 -> :ok end)
      reject(&PlayerSession.apply_damage/3)

      test_pid = self()

      stub(StatusInterpreter, :remove_status, fn unit_type, unit_id, :sc_sv_roottwist ->
        send(test_pid, {:root_twist_removed, unit_type, unit_id})
        :ok
      end)

      assert {:ok, ^caster} =
               WzHeavendrive.cast(caster, {:ground, 150, 150}, 1, WzHeavendrive.definition())

      assert_received {:root_twist_removed, :mob, 2_001}
      assert_received {:root_twist_removed, :mob, 2_002}
      refute_received {:root_twist_removed, _, 2_003}
      refute_received {:root_twist_removed, :player, _}
      refute_received {:root_twist_removed, _, 1_000}
    end
  end

  describe "Interpreter.cast/4 ground validation" do
    test "rejects a Heaven's Drive cell beyond its 9-cell range" do
      stub(Catalog, :by_id, fn 91 -> {:ok, WzHeavendrive.definition()} end)

      assert {:error, :out_of_range} =
               Interpreter.cast(interpreter_state(), 91, 1, {:ground, 20, 10})
    end

    test "rejects a Heaven's Drive cell that is not walkable" do
      map =
        "prontera"
        |> MapData.new(20, 20)
        |> MapData.set_cell(12, 12, GatType.wall())

      stub(Catalog, :by_id, fn 91 -> {:ok, WzHeavendrive.definition()} end)
      stub(MapCache, :get, fn "prontera" -> {:ok, map} end)

      assert {:error, :invalid_target} =
               Interpreter.cast(interpreter_state(), 91, 1, {:ground, 12, 12})
    end

    test "rejects an in-range Heaven's Drive coordinate outside the map bounds" do
      map = MapData.new("prontera", 12, 12)

      stub(Catalog, :by_id, fn 91 -> {:ok, WzHeavendrive.definition()} end)
      stub(MapCache, :get, fn "prontera" -> {:ok, map} end)

      assert {:error, :invalid_target} =
               Interpreter.cast(interpreter_state(), 91, 1, {:ground, 12, 10})
    end
  end
end
