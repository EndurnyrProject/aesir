defmodule Aesir.ZoneServer.Mmo.Skills.WzVermilionTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.WzVermilion
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!
  setup :setup_ets_tables

  @caster_id 1000
  @map_name "prontera"
  @center {150, 150}

  defp group(attrs \\ []) do
    struct(
      %Group{
        group_id: 1,
        skill_id: 85,
        skill_name: :wz_vermilion,
        level: 10,
        caster_id: @caster_id,
        caster_type: :player,
        map_name: @map_name,
        center: @center,
        cells: [],
        interval: 1_250,
        state: %{}
      },
      attrs
    )
  end

  defp start_manager(opts \\ []) do
    manager =
      start_supervised!(
        {Manager,
         Keyword.merge(
           [
             name: nil,
             schedule_tick: fn _pid, _interval -> :ok end,
             unit_available?: fn _unit_type, _unit_id, _map_name -> true end
           ],
           opts
         )}
      )

    allow(Catalog, self(), manager)
    allow(Combat, self(), manager)
    allow(StatusInterpreter, self(), manager)
    manager
  end

  describe "on_place/1" do
    test "creates the canonical 13x13 Wind field and timing" do
      assert {:ok, placement} = WzVermilion.on_place(group())

      assert length(placement.cells) == 169
      assert {144, 144} in placement.cells
      assert {156, 156} in placement.cells
      assert placement.interval == 1_250
      assert placement.initial_delay == 0
      assert placement.duration == 18_000
      assert placement.lifecycle_policy.on_caster_loss == :skip_action
    end
  end

  describe "definition/0" do
    test "matches the Renewal level tables" do
      definition = WzVermilion.definition()

      assert definition.id == 85
      assert definition.max_level == 10
      assert definition.target_type == :ground
      assert definition.damage_kind == :magic
      assert definition.element == :wind
      assert definition.range == 9
      assert definition.splash_radius == 6
      assert definition.hit_interval == 1_250
      assert definition.hit_count == 20
      assert definition.unit_duration == List.duplicate(18_000, 10)
      assert definition.duration == List.duplicate(18_000, 10)
      assert definition.sp_cost == [60, 64, 68, 72, 76, 80, 84, 88, 92, 96]
      assert definition.cast_time == [6300, 6100, 5900, 5700, 5500, 5300, 5100, 4900, 4700, 4500]
      assert definition.fixed_cast_time == List.duplicate(1_500, 10)
      assert definition.after_cast_delay == List.duplicate(1_000, 10)
      assert definition.cooldown == List.duplicate(5_000, 10)
    end
  end

  describe "on_interval/2" do
    test "hits each eligible target and delegates an independent resistance-aware Blind attempt" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

      stub(Combat, :splash_targets, fn @map_name, @center, 6, @caster_id ->
        [{:mob, 2001}, {:player, 2002}]
      end)

      expect(Combat, :apply_skill_unit_damage, 2, fn
        %{unit_id: @caster_id}, unit_type, target_id, 85, 10, :wind, 1_400, -20
        when {unit_type, target_id} in [{:mob, 2001}, {:player, 2002}] ->
          :ok
      end)

      expect(StatusInterpreter, :apply_status, 2, fn
        unit_type, target_id, :sc_blind, [val1: 10, duration: 18_000, success_rate: 60]
        when {unit_type, target_id} in [{:mob, 2001}, {:player, 2002}] ->
          :ok
      end)

      assert {:ok, %Group{}} = WzVermilion.on_interval(group(), 1_250)
    end

    test "does not attempt Blind when the target is no longer valid for damage" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
      stub(Combat, :splash_targets, fn @map_name, @center, 6, @caster_id -> [{:mob, 2001}] end)

      stub(Combat, :apply_skill_unit_damage, fn _caster, _type, _id, 85, 10, :wind, 1_400, -20 ->
        {:error, :target_not_found}
      end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{}} = WzVermilion.on_interval(group(), 1_250)
    end
  end

  describe "manager cadence" do
    test "hits on the first manager cadence, continues every 1,250ms, then expires at 18s" do
      test_pid = self()
      stub(Catalog, :ground_module_for, fn :wz_vermilion -> {:ok, WzVermilion} end)
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
      stub(Combat, :splash_targets, fn @map_name, @center, 6, @caster_id -> [{:mob, 2001}] end)

      stub(Combat, :apply_skill_unit_damage, fn _caster, :mob, 2001, 85, 10, :wind, 1_400, -20 ->
        send(test_pid, :hit)
        :ok
      end)

      stub(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_blind, _params -> :ok end)

      manager = start_manager()

      :ok =
        Manager.register(
          manager,
          group(next_tick_at: 0, expires_at: 18_000)
        )

      assert :ok = Manager.tick(manager, 0)
      assert_received :hit

      assert :ok = Manager.tick(manager, 1_249)
      refute_received :hit

      for tick <- 1_250..17_500//1_250 do
        assert :ok = Manager.tick(manager, tick)
        assert_received :hit
      end

      assert %Group{next_tick_at: 18_750} = Storage.get(1)

      assert :ok = Manager.tick(manager, 18_000)
      refute_received :hit
      assert Storage.get(1) == nil
    end

    test "skips hits after caster loss while retaining the field until its normal expiry" do
      manager = start_manager(unit_available?: fn _type, _id, _map -> false end)

      assert {:ok, placement} = WzVermilion.on_place(group())

      :ok =
        Manager.register(
          manager,
          group(
            next_tick_at: 1_250,
            expires_at: 18_000,
            lifecycle_policy: placement.lifecycle_policy
          )
        )

      reject(&Combat.resolve_combatant/1)
      reject(&Combat.splash_targets/4)
      reject(&Combat.apply_skill_unit_damage/8)
      reject(&StatusInterpreter.apply_status/4)

      assert :ok = Manager.tick(manager, 1_250)
      assert %Group{next_tick_at: 2_500} = Storage.get(1)

      assert :ok = Manager.tick(manager, 18_000)
      assert Storage.get(1) == nil
    end
  end
end
