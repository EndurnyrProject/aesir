defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnAutocounterTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnAutocounter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  setup :set_mimic_from_context
  setup :verify_on_exit!

  describe "cast/4" do
    test "arms sc_auto_counter on the caster for 400 * level ms carrying the level in val1" do
      test_pid = self()
      caster = %PlayerState{character_id: 4001}
      {:ok, definition} = Catalog.by_id(61)

      stub(StatusInterpreter, :apply_status, fn :player, 4001, :sc_auto_counter, params ->
        send(test_pid, {:applied, params})
        :ok
      end)

      assert {:ok, ^caster} = KnAutocounter.cast(caster, :self, 3, definition)

      assert_received {:applied, params}
      assert Keyword.fetch!(params, :val1) == 3
      assert Keyword.fetch!(params, :duration) == 1_200
      assert Keyword.fetch!(params, :caster_id) == 4001
    end

    test "schedules the stance's visual 100 ms after the cast, at its level and map" do
      caster = %{caster_state() | character_id: 4003}
      {:ok, definition} = Catalog.by_id(61)

      stub(StatusInterpreter, :apply_status, fn :player, 4003, :sc_auto_counter, _params ->
        :ok
      end)

      started = System.monotonic_time(:millisecond)
      assert {:ok, ^caster} = KnAutocounter.cast(caster, {:unit, 9003}, 4, definition)

      assert_receive {:skill, {:deferred, KnAutocounter, {4, "prontera"}}}, 1_000
      assert System.monotonic_time(:millisecond) - started >= 100
    end

    test "keeps the cast when the counter status is refused" do
      caster = %PlayerState{character_id: 4002}
      {:ok, definition} = Catalog.by_id(61)

      stub(StatusInterpreter, :apply_status, fn :player, 4002, :sc_auto_counter, _params ->
        {:error, :immune}
      end)

      assert {:ok, ^caster} = KnAutocounter.cast(caster, {:unit, 9002}, 5, definition)
    end
  end

  describe "deferred/2" do
    test "shows the armed stance through the skill effect packet" do
      caster = caster_state()
      test_pid = self()

      stub(Broadcast, :to_in_range, fn map_name, x, y, _range, packet ->
        send(test_pid, {:broadcast, map_name, x, y, packet})
        :ok
      end)

      assert :ok = KnAutocounter.deferred({3, "prontera"}, caster)

      assert_received {:broadcast, "prontera", 10, 20,
                       %SkillEffect{
                         skill_id: 61,
                         level: 3,
                         src_id: 4004,
                         target_id: 4004,
                         result: 1
                       }}
    end

    test "shows the stance for a monster caster too" do
      caster = %MobState{
        instance_id: 5001,
        mob_id: 1_002,
        mob_data: nil,
        spawn_ref: nil,
        map_name: "prontera",
        x: 5,
        y: 6,
        hp: 100,
        sp: 0,
        spawned_at: 0
      }

      test_pid = self()

      stub(Broadcast, :to_in_range, fn map_name, x, y, _range, packet ->
        send(test_pid, {:broadcast, map_name, x, y, packet})
        :ok
      end)

      assert :ok = KnAutocounter.deferred({2, "prontera"}, caster)

      assert_received {:broadcast, "prontera", 5, 6,
                       %SkillEffect{skill_id: 61, level: 2, src_id: 5001, target_id: 5001}}
    end

    test "shows nothing when the caster died before the delayed visual" do
      caster = put_in(caster_state().stats.current_state.hp, 0)

      reject(&Broadcast.to_in_range/5)

      assert :ok = KnAutocounter.deferred({3, "prontera"}, caster)
    end

    test "shows nothing when the caster changed map before the delayed visual" do
      caster = %{caster_state() | map_name: "geffen"}

      reject(&Broadcast.to_in_range/5)

      assert :ok = KnAutocounter.deferred({3, "prontera"}, caster)
    end

    defp caster_state do
      PlayerStateFixture.build(%{
        character_id: 4004,
        map_name: "prontera",
        x: 10,
        y: 20,
        stats: %PlayerStats{}
      })
    end
  end

  describe "definition" do
    test "both modes allow unarmed and sword counters but not bows" do
      renewal = KnAutocounter.definition(:renewal)
      classic = KnAutocounter.definition(:pre_renewal)

      assert :fist in renewal.require_weapon
      assert :one_handed_sword in renewal.require_weapon
      refute :bow in renewal.require_weapon
      assert classic.require_weapon == renewal.require_weapon
    end
  end
end
