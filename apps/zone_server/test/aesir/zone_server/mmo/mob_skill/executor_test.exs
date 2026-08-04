defmodule Aesir.ZoneServer.Mmo.MobSkill.ExecutorTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Net.SkillCasting
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Catalog, as: SkillCatalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @map "prontera"

  defmodule CastOnly do
    @moduledoc false
    @behaviour Active

    @impl Active
    def validate(_caster, _target, _level, _definition), do: :ok

    @impl Active
    def cast(caster, target, level, definition) do
      send(self(), {:cast, caster.instance_id, target, level, definition.id})
      {:ok, caster}
    end
  end

  defmodule OriginAware do
    @moduledoc false
    @behaviour Active

    @impl Active
    def validate(_caster, _target, _level, _definition), do: :ok

    @impl Active
    def cast(caster, _target, _level, _definition), do: {:ok, caster}

    @impl Active
    def cast_with_origin(caster, target, level, definition, origin) do
      send(self(), {:origin_cast, target, level, definition.id, origin})
      {:ok, caster}
    end
  end

  defmodule MobCastPreferred do
    @moduledoc false
    @behaviour Active

    @impl Active
    def validate(_caster, _target, _level, _definition), do: :ok

    @impl Active
    def cast(_caster, _target, _level, _definition), do: {:error, :cast_should_not_run}

    @impl Active
    def mob_cast(caster, raw_target, level, definition, row) do
      send(
        self(),
        {:mob_cast, caster.instance_id, raw_target, level, definition.id, row.skill_id}
      )

      :ok
    end
  end

  defmodule ValidateAborts do
    @moduledoc false
    @behaviour Active

    @impl Active
    def validate(_caster, _target, _level, _definition), do: {:error, :not_allowed}

    @impl Active
    def cast(_caster, _target, _level, _definition), do: {:error, :cast_should_not_run}
  end

  defp mob(overrides \\ %{}) do
    base = %{
      instance_id: 5001,
      mob_id: 1002,
      map_name: @map,
      x: 100,
      y: 100,
      target_ref: {:player, 42},
      hp: 500,
      max_hp: 500,
      mob_data: mob_data()
    }

    struct(MobState, Map.merge(base, Map.new(overrides)))
  end

  defp mob_data(overrides \\ %{}) do
    base = %{id: 1002, matk: 60, attack_range: 1, skill_range: 10}
    struct(MobDefinition, Map.merge(base, Map.new(overrides)))
  end

  defp row(overrides \\ %{}) do
    base = %{
      skill: "UNRESOLVED_TEST_SKILL",
      skill_id: 999_999,
      state: :attack,
      level: 3,
      rate: 10_000,
      cast_time: 800,
      delay: 5_000,
      cancelable: false,
      target: :target,
      condition: %{type: :always},
      emotion: nil
    }

    Map.merge(base, Map.new(overrides))
  end

  defp definition(overrides) do
    base = %{id: 9001, name: :fake_skill, display_name: "Fake Skill", max_level: 5}
    struct(Definition, Map.merge(base, Map.new(overrides)))
  end

  defp friend_state(instance_id, mob_id, hp, dead? \\ false) do
    struct(MobState,
      instance_id: instance_id,
      mob_id: mob_id,
      hp: hp,
      max_hp: 1000,
      is_dead: dead?
    )
  end

  defp player_state(id, action_state \\ :idle, hp \\ 100) do
    %PlayerState{
      character_id: id,
      action_state: action_state,
      stats: %{current_state: %{hp: hp}}
    }
  end

  defp homunculus_state(gid, hp) do
    %HomunculusState{
      id: gid,
      owner_character_id: 42,
      class_id: 6001,
      name: "Lif",
      world_gid: gid,
      lifecycle: if(hp > 0, do: :active, else: :dead),
      action_state: if(hp > 0, do: :idle, else: :dead),
      hp: hp
    }
  end

  defp stub_living_player_target(id \\ 42) do
    stub(UnitRegistry, :get_unit, fn :player, ^id ->
      {:ok, {PlayerState, player_state(id), self()}}
    end)
  end

  defp stub_skill(skill_id, name, module, definition_overrides \\ %{}) do
    defn = definition(Map.merge(%{id: skill_id, name: name}, definition_overrides))
    stub(SkillCatalog, :by_id, fn ^skill_id -> {:ok, defn} end)
    stub(SkillCatalog, :active_module_for, fn ^name -> {:ok, module} end)
  end

  describe "resolve_target/2" do
    test ":target resolves to the current target player" do
      stub_living_player_target()

      assert Executor.resolve_target(mob(), row(%{target: :target})) ==
               {:ok, {:unit, :player, 42}}
    end

    test ":target with no target errors" do
      assert Executor.resolve_target(mob(%{target_ref: nil}), row(%{target: :target})) ==
               {:error, :no_target}
    end

    test ":target rejects a stale current target" do
      stub(UnitRegistry, :get_unit, fn :player, 42 -> {:error, :not_found} end)

      assert Executor.resolve_target(mob(), row(%{target: :target})) == {:error, :no_target}
    end

    test ":self resolves to the caster" do
      assert Executor.resolve_target(mob(), row(%{target: :self})) == {:ok, {:unit, :mob, 5001}}
    end

    test ":master resolves to the master mob" do
      stub(UnitRegistry, :get_unit, fn :mob, 7_001 ->
        {:ok, {MobState, friend_state(7_001, 1002, 100), self()}}
      end)

      assert Executor.resolve_target(mob(%{master_id: 7001}), row(%{target: :master})) ==
               {:ok, {:unit, :mob, 7001}}
    end

    test ":master with no master errors" do
      assert Executor.resolve_target(mob(), row(%{target: :master})) == {:error, :no_master}
    end

    test ":master rejects a dead master mob" do
      stub(UnitRegistry, :get_unit, fn :mob, 7_001 ->
        {:ok, {MobState, friend_state(7_001, 1002, 0, true), self()}}
      end)

      assert Executor.resolve_target(mob(%{master_id: 7_001}), row(%{target: :master})) ==
               {:error, :no_master}
    end

    test ":friend resolves to the lowest-HP living mob of the same class in skill range" do
      stub(SpatialIndex, :get_units_in_range, fn :mob, @map, 100, 100, 10 ->
        [5001, 6001, 6002, 6003, 6004, 6005]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 6001 -> {:ok, {MobState, friend_state(6001, 1002, 300), self()}}
        :mob, 6002 -> {:ok, {MobState, friend_state(6002, 1002, 100), self()}}
        :mob, 6003 -> {:ok, {MobState, friend_state(6003, 9999, 10), self()}}
        :mob, 6004 -> {:ok, {MobState, friend_state(6004, 1002, 5, true), self()}}
        :mob, 6005 -> {:ok, {MobState, friend_state(6005, 1002, 0), self()}}
      end)

      assert Executor.resolve_target(mob(), row(%{target: :friend})) ==
               {:ok, {:unit, :mob, 6002}}
    end

    test ":friend excludes the caster itself and errors when no friend is around" do
      stub(SpatialIndex, :get_units_in_range, fn :mob, @map, 100, 100, 10 -> [5001] end)

      assert Executor.resolve_target(mob(), row(%{target: :friend})) == {:error, :no_friend}
    end

    test ":randomtarget resolves to a player in skill range" do
      stub(SpatialIndex, :get_units_in_range, fn
        :player, @map, 100, 100, 10 -> [7]
        :homunculus, @map, 100, 100, 10 -> []
      end)

      stub(UnitRegistry, :get_unit, fn :player, 7 ->
        {:ok, {PlayerState, player_state(7), self()}}
      end)

      assert Executor.resolve_target(mob(), row(%{target: :randomtarget})) ==
               {:ok, {:unit, :player, 7}}
    end

    test ":randomtarget selects a living Homunculus when it is the only candidate" do
      gid = 1_500_007

      stub(SpatialIndex, :get_units_in_range, fn
        :player, @map, 100, 100, 10 -> []
        :homunculus, @map, 100, 100, 10 -> [gid]
      end)

      stub(UnitRegistry, :get_unit, fn :homunculus, ^gid ->
        {:ok, {HomunculusState, homunculus_state(gid, 100), self()}}
      end)

      assert Executor.resolve_target(mob(), row(%{target: :randomtarget})) ==
               {:ok, {:unit, :homunculus, gid}}
    end

    test ":randomtarget excludes dead and stale Homunculi" do
      dead_gid = 1_500_008
      stale_gid = 1_500_009

      stub(SpatialIndex, :get_units_in_range, fn
        :player, @map, 100, 100, 10 -> []
        :homunculus, @map, 100, 100, 10 -> [dead_gid, stale_gid]
      end)

      stub(UnitRegistry, :get_unit, fn
        :homunculus, ^dead_gid ->
          {:ok, {HomunculusState, homunculus_state(dead_gid, 0), self()}}

        :homunculus, ^stale_gid ->
          {:error, :not_found}
      end)

      assert Executor.resolve_target(mob(), row(%{target: :randomtarget})) ==
               {:error, :no_target}
    end

    test ":randomtarget excludes an indexed corpse in skill range" do
      stub(SpatialIndex, :get_units_in_range, fn
        :player, @map, 100, 100, 10 -> [7]
        :homunculus, @map, 100, 100, 10 -> []
      end)

      stub(UnitRegistry, :get_unit, fn :player, 7 ->
        {:ok, {PlayerState, player_state(7, :dead, 0), self()}}
      end)

      assert Executor.resolve_target(mob(), row(%{target: :randomtarget})) == {:error, :no_target}
    end

    test ":randomtarget errors when no player is in range" do
      stub(SpatialIndex, :get_units_in_range, fn
        :player, @map, 100, 100, 10 -> []
        :homunculus, @map, 100, 100, 10 -> []
      end)

      assert Executor.resolve_target(mob(), row(%{target: :randomtarget})) ==
               {:error, :no_target}
    end

    test ":around resolves to a ground cell at the caster" do
      assert Executor.resolve_target(mob(), row(%{target: :around})) ==
               {:ok, {:ground, 100, 100, :around}}
    end

    test ":around2 resolves to a ground cell at the caster" do
      assert Executor.resolve_target(mob(), row(%{target: :around2})) ==
               {:ok, {:ground, 100, 100, :around2}}
    end

    test ":around5 resolves to a ground cell at the target" do
      stub(SpatialIndex, :get_unit_position, fn :player, 42 -> {:ok, {110, 111, @map}} end)

      stub(UnitRegistry, :get_unit, fn :player, 42 ->
        {:ok, {PlayerState, player_state(42), self()}}
      end)

      assert Executor.resolve_target(mob(), row(%{target: :around5})) ==
               {:ok, {:ground, 110, 111, :around5}}
    end

    test ":around5 errors when the target position is gone" do
      stub(SpatialIndex, :get_unit_position, fn :player, 42 -> {:error, :not_found} end)

      assert Executor.resolve_target(mob(), row(%{target: :around5})) == {:error, :no_target}
    end

    test ":around5 with no target errors" do
      assert Executor.resolve_target(mob(%{target_ref: nil}), row(%{target: :around5})) ==
               {:error, :no_target}
    end
  end

  describe "execute/2 dispatch" do
    test "dispatches MG_FIREBOLT (a real skill) through the real skill module's cast" do
      caster = mob()
      stub_living_player_target()

      expect(Combat, :execute_magic_attack, fn passed_caster, 42, opts ->
        assert passed_caster.instance_id == caster.instance_id
        assert opts[:skill_id] == 19
        assert opts[:skill_level] == 3
        assert opts[:hit_count] == 3
        assert opts[:element] == :fire
        :ok
      end)

      assert Executor.execute(caster, row(%{skill_id: 19, target: :target})) == :ok
    end

    test "dispatches BA_DISSONANCE self rows through its real one-shot splash" do
      caster = mob()

      expect(Combat, :execute_magic_splash, fn passed_caster, {100, 100}, 4, opts ->
        assert passed_caster.instance_id == caster.instance_id
        assert opts[:skill_id] == 317
        assert opts[:skill_level] == 5
        assert opts[:skill_ratio] == 360
        assert opts[:element] == :neutral
        assert opts[:split] == false
        []
      end)

      dissonance_row =
        row(%{skill: "BA_DISSONANCE", skill_id: 317, level: 5, target: :self})

      assert Executor.execute(caster, dissonance_row) == :ok
    end

    test "dispatches imported BA_MUSICALSTRIKE rows through its real mob attack path" do
      caster = mob()
      stub_living_player_target()

      expect(Combat, :execute_skill_attack, fn passed_caster, 42, opts ->
        assert passed_caster.instance_id == caster.instance_id
        assert opts[:skill_id] == 316
        assert opts[:skill_level] == 5
        assert opts[:skill_ratio] == 310
        assert opts[:display_hit_count] == 2
        :ok
      end)

      musical_strike_row =
        row(%{skill: "BA_MUSICALSTRIKE", skill_id: 316, level: 5, target: :target})

      assert Executor.execute(caster, musical_strike_row) == :ok
    end

    test "dispatches imported BA_FROSTJOKER self rows through its deferred mob path" do
      frost_joker_row =
        row(%{skill: "BA_FROSTJOKER", skill_id: 318, level: 3, target: :self})

      assert Executor.execute(mob(), frost_joker_row) == :ok
      refute_received {:skill, {:deferred, _, _}}
    end

    test "an imported Frost Diver row preserves a typed Homunculus status target and mob source" do
      gid = 1_500_010
      caster = mob(%{target_ref: {:homunculus, gid}})

      stub(UnitRegistry, :get_unit, fn :homunculus, ^gid ->
        {:ok, {HomunculusState, homunculus_state(gid, 100), self()}}
      end)

      expect(Combat, :execute_magic_attack, fn ^caster, {:homunculus, ^gid}, opts ->
        assert opts[:skill_id] == 15
        assert opts[:skill_level] == 40
        :ok
      end)

      expect(StatusInterpreter, :apply_status, fn :homunculus, ^gid, :sc_freeze, opts ->
        assert opts[:caster_id] == caster.instance_id
        assert opts[:source_type] == :mob
        :ok
      end)

      imported_row = row(%{skill: "MG_FROSTDIVER", skill_id: 15, level: 40, target: :target})
      assert Executor.execute(caster, imported_row) == :ok
    end

    test "dispatches BA_PANGVOICE through its real mob status path" do
      stub(UnitRegistry, :get_player_pid, fn 42 -> {:ok, self()} end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 42 -> {:error, :not_found}
        :player, 42 -> {:ok, {PlayerState, player_state(42), self()}}
      end)

      expect(StatusInterpreter, :apply_status, 2, fn :player, 42, status, opts ->
        assert opts == [
                 duration: 10_000,
                 success_rate: 100,
                 caster_id: 5001,
                 source_type: :mob
               ]

        send(self(), {:status_attempted, status})

        case status do
          :sc_confusion -> {:error, :resisted}
          :sc_bleeding -> :ok
        end
      end)

      pang_voice_row =
        row(%{skill: "BA_PANGVOICE", skill_id: 1010, level: 1, target: :target})

      assert Executor.execute(mob(), pang_voice_row) == :ok
      assert_received {:status_attempted, :sc_confusion}
      assert_received {:status_attempted, :sc_bleeding}
    end

    test "adapts a unit target from {:unit, type, id} to {:unit, id} for cast/4" do
      stub_skill(9001, :fake_skill, CastOnly)
      stub_living_player_target()

      assert Executor.execute(mob(), row(%{skill_id: 9001, target: :target})) == :ok
      assert_received {:cast, 5001, {:unit, 42}, 3, 9001}
    end

    test "adapts a ground target from {:ground, x, y, area} to {:ground, x, y} for cast/4" do
      stub_skill(9002, :fake_skill, CastOnly)

      assert Executor.execute(mob(), row(%{skill_id: 9002, target: :around})) == :ok
      assert_received {:cast, 5001, {:ground, 100, 100}, 3, 9002}
    end

    test "adapts a self target from {:unit, :mob, id} to {:unit, id}, never a bare :self" do
      stub_skill(9003, :fake_skill, CastOnly)

      assert Executor.execute(mob(), row(%{skill_id: 9003, target: :self})) == :ok
      assert_received {:cast, 5001, {:unit, 5001}, 3, 9003}
    end

    test "a ground-definition skill centers its cell on a unit-shaped target row" do
      stub_skill(9007, :fake_skill, CastOnly, %{target_type: :ground})
      stub_living_player_target()
      stub(SpatialIndex, :get_unit_position, fn :player, 42 -> {:ok, {200, 201, @map}} end)

      assert Executor.execute(mob(), row(%{skill_id: 9007, target: :target})) == :ok
      assert_received {:cast, 5001, {:ground, 200, 201}, 3, 9007}
    end

    test "a ground-definition skill with a self-target row centers on the caster's own cell" do
      stub_skill(9008, :fake_skill, CastOnly, %{target_type: :ground})
      reject(&SpatialIndex.get_unit_position/2)

      assert Executor.execute(mob(), row(%{skill_id: 9008, target: :self})) == :ok
      assert_received {:cast, 5001, {:ground, 100, 100}, 3, 9008}
    end

    test "a ground-definition skill aborts with :no_target when the unit's cell cannot be resolved" do
      stub_skill(9009, :fake_skill, CastOnly, %{target_type: :ground})
      stub_living_player_target()
      stub(SpatialIndex, :get_unit_position, fn :player, 42 -> {:error, :not_found} end)

      assert Executor.execute(mob(), row(%{skill_id: 9009, target: :target})) ==
               {:error, :no_target}

      refute_received {:cast, _, _, _, _}
    end

    test "dispatches mob origin when the skill supports origin-aware casting" do
      stub_skill(9010, :fake_skill, OriginAware, %{target_type: :ground})

      assert Executor.execute(mob(), row(%{skill_id: 9010, target: :self})) == :ok
      assert_received {:origin_cast, {:ground, 100, 100}, 3, 9010, :mob}
    end

    test "prefers mob_cast/5 over cast/4 when the module exports it, with the raw target and full row" do
      stub_skill(9004, :fake_skill, MobCastPreferred)
      stub_living_player_target()

      assert Executor.execute(mob(), row(%{skill_id: 9004, target: :target})) == :ok
      assert_received {:mob_cast, 5001, {:unit, :player, 42}, 3, 9004, 9004}
    end

    test "aborts cleanly on a failed validate/4, never running cast/4 or mob_cast/5" do
      stub_skill(9005, :fake_skill, ValidateAborts)

      assert Executor.execute(mob(), row(%{skill_id: 9005, target: :self})) ==
               {:error, :not_allowed}
    end

    test "is a no-op when the skill id is not in the catalog" do
      assert Executor.execute(mob(), row(%{skill_id: 999_999, target: :self})) == :ok
    end

    test "is a no-op when the skill has no active module" do
      stub(SkillCatalog, :by_id, fn 9006 -> {:ok, definition(%{id: 9006, name: :no_active})} end)
      stub(SkillCatalog, :active_module_for, fn :no_active -> :error end)

      assert Executor.execute(mob(), row(%{skill_id: 9006, target: :self})) == :ok
    end

    test "propagates a target resolution error without dispatching" do
      reject(&Combat.execute_magic_attack/3)

      assert Executor.execute(mob(%{target_ref: nil}), row()) == {:error, :no_target}
    end

    test "fires the mob emote on a successfully-resolved cast when the row has one" do
      caster = mob()
      stub_living_player_target()

      expect(Emote, :show, fn {:mob, instance_id}, 3 ->
        assert instance_id == caster.instance_id
        :ok
      end)

      assert Executor.execute(caster, row(%{emotion: 3})) == :ok
    end

    test "does not fire an emote when the row has none" do
      stub_living_player_target()
      reject(&Emote.show/2)

      assert Executor.execute(mob(), row(%{emotion: nil})) == :ok
    end

    test "does not fire an emote when target resolution fails" do
      reject(&Emote.show/2)
      reject(&Combat.execute_magic_attack/3)

      assert Executor.execute(mob(%{target_ref: nil}), row(%{emotion: 3})) == {:error, :no_target}
    end
  end

  describe "broadcast_casting/2" do
    test "broadcasts a SkillCasting packet with property from the skill's element" do
      test_pid = self()

      expect(Broadcast, :to_in_range, fn @map, 100, 100, range, packet ->
        assert range == Config.view_range()
        send(test_pid, {:packet, packet})
        :ok
      end)

      assert Executor.broadcast_casting(mob(), row(%{skill_id: 19})) == :ok

      fire = ElementModifiers.id(:fire)

      assert_received {:packet,
                       %SkillCasting{
                         src_id: 5001,
                         target_id: 42,
                         skill_id: 19,
                         property: ^fire,
                         cast_time: 800
                       }}
    end

    test "uses property 0 and target 0 for a skill unresolvable in the skill catalog and no target" do
      test_pid = self()

      expect(Broadcast, :to_in_range, fn @map, 100, 100, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      caster = mob(%{target_ref: nil})

      assert Executor.broadcast_casting(caster, row()) == :ok

      assert_received {:packet, %SkillCasting{target_id: 0, property: 0}}
    end
  end
end
