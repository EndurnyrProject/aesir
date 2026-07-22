defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSummonslaveTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcSummonslave
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  @caster_id 5001
  @map "prontera"

  defp caster do
    struct(MobState, %{instance_id: @caster_id, map_name: @map, x: 100, y: 100})
  end

  defp row(vals, level \\ 2) do
    condition =
      Map.merge(
        %{type: :onspawn, value: 0, val1: nil, val2: nil, val3: nil, val4: nil, val5: nil},
        Map.new(vals)
      )

    %{
      skill: "NPC_SUMMONSLAVE",
      skill_id: 196,
      state: :idle,
      level: level,
      rate: 10_000,
      cast_time: 0,
      delay: 0,
      cancelable: false,
      target: :self,
      condition: condition,
      emotion: nil
    }
  end

  defp register_slave(instance_id, master_id, dead? \\ false) do
    state = struct(MobState, %{instance_id: instance_id, master_id: master_id, is_dead: dead?})
    UnitRegistry.register_unit(:mob, instance_id, MobState, state, nil)
  end

  defp expect_summons(count) do
    test_pid = self()

    expect(Coordinator, :summon_mob, count, fn map, mob_id, x, y, opts ->
      send(test_pid, {:summon, map, mob_id, x, y, opts})
      {:ok, System.unique_integer([:positive])}
    end)
  end

  describe "Catalog" do
    test "by_id/1 resolves npc_summonslave with correct definition" do
      assert {:ok, defn} = Catalog.by_id(196)
      assert defn.name == :npc_summonslave
      assert defn.display_name == "Summon Slave"
      assert defn.max_level == 16
      assert defn.target_type == :self
      assert defn.damage_type == :no_damage
    end

    test "by_name/1 resolves :npc_summonslave" do
      assert {:ok, %{id: 196}} = Catalog.by_name(:npc_summonslave)
    end

    test "the skill has an active module" do
      assert {:ok, NpcSummonslave} = Catalog.active_module_for(:npc_summonslave)
    end
  end

  describe "cast/4" do
    test "is a mob-only stub" do
      {:ok, definition} = Catalog.by_id(196)

      assert NpcSummonslave.cast(caster(), :self, 2, definition) == {:error, :mob_only}
    end
  end

  describe "mob_cast/5" do
    test "summons `level` slaves of the row's val id near the caster with master_id set" do
      {:ok, definition} = Catalog.by_id(196)
      expect_summons(2)

      assert NpcSummonslave.mob_cast(
               caster(),
               {:unit, :mob, @caster_id},
               2,
               definition,
               row(val1: 1100)
             ) ==
               :ok

      assert_received {:summon, @map, 1100, 100, 100, [master_id: @caster_id]}
      assert_received {:summon, @map, 1100, 100, 100, [master_id: @caster_id]}
      refute_received {:summon, _, _, _, _, _}
    end

    test "cycles through multiple val ids (rAthena mob_summonslave semantics)" do
      {:ok, definition} = Catalog.by_id(196)
      expect_summons(3)

      assert NpcSummonslave.mob_cast(
               caster(),
               {:unit, :mob, @caster_id},
               3,
               definition,
               row(val1: 1100, val2: 1101)
             ) == :ok

      assert_received {:summon, @map, 1100, _, _, _}
      assert_received {:summon, @map, 1101, _, _, _}
      assert_received {:summon, @map, 1100, _, _, _}
    end

    test "summons nothing when the per-master cap is already reached" do
      {:ok, definition} = Catalog.by_id(196)
      Enum.each(9101..9105, &register_slave(&1, @caster_id))
      reject(&Coordinator.summon_mob/5)

      assert NpcSummonslave.mob_cast(
               caster(),
               {:unit, :mob, @caster_id},
               2,
               definition,
               row(val1: 1100)
             ) ==
               :ok
    end

    test "summons only up to the remaining cap headroom" do
      {:ok, definition} = Catalog.by_id(196)
      Enum.each(9101..9104, &register_slave(&1, @caster_id))
      expect_summons(1)

      assert NpcSummonslave.mob_cast(
               caster(),
               {:unit, :mob, @caster_id},
               2,
               definition,
               row(val1: 1100)
             ) ==
               :ok

      assert_received {:summon, @map, 1100, _, _, _}
      refute_received {:summon, _, _, _, _, _}
    end

    test "errors cleanly when the row carries no valid slave id" do
      {:ok, definition} = Catalog.by_id(196)
      reject(&Coordinator.summon_mob/5)

      assert NpcSummonslave.mob_cast(caster(), {:unit, :mob, @caster_id}, 2, definition, row([])) ==
               {:error, :no_slave_ids}

      assert NpcSummonslave.mob_cast(
               caster(),
               {:unit, :mob, @caster_id},
               2,
               definition,
               row(val1: 0)
             ) ==
               {:error, :no_slave_ids}
    end
  end

  describe "Executor integration" do
    test "the executor dispatches through mob_cast/5, not cast/4" do
      expect_summons(1)

      assert Executor.execute(caster(), row([val1: 1100], 1)) == :ok

      assert_received {:summon, @map, 1100, 100, 100, [master_id: @caster_id]}
    end
  end
end
