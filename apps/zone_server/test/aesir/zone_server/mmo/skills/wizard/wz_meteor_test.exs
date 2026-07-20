defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzMeteorTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzMeteor
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :setup_ets_tables
  setup :verify_on_exit!

  @caster_id 1000
  @map_name "prontera"
  @center {150, 150}

  defp group(attrs) do
    struct(
      %Group{
        group_id: 1,
        skill_id: 83,
        skill_name: :wz_meteor,
        level: 1,
        caster_id: @caster_id,
        caster_type: :player,
        map_name: @map_name,
        center: @center,
        cells: [@center],
        created_at: 0,
        interval: 1_000,
        state: %{}
      },
      attrs
    )
  end

  defp start_manager(opts) do
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

  test "matches Renewal data" do
    definition = WzMeteor.definition()

    assert definition.id == 83
    assert definition.target_type == :ground
    assert definition.damage_kind == :magic
    assert definition.element == :fire
    assert definition.range == 9
    assert definition.splash_radius == 3
    assert definition.hit_count == 2
    assert definition.unit_duration == List.duplicate(4_500, 10)

    assert definition.duration == [
             2_000,
             3_000,
             3_000,
             4_000,
             4_000,
             5_000,
             5_000,
             6_000,
             6_000,
             7_000
           ]

    assert definition.sp_cost == [20, 24, 30, 34, 40, 44, 50, 54, 60, 64]
    assert definition.fixed_cast_time == List.duplicate(1_500, 10)
  end

  test "places one manager-owned schedule with the rAthena first-impact timing" do
    assert {:ok, placement} = WzMeteor.on_place(group([]))

    assert placement.cells == [@center]
    assert placement.interval == 1_000
    assert placement.initial_delay == 700
    assert placement.duration == 2_000
    assert placement.lifecycle_policy.on_caster_loss == :skip_action
    assert placement.state == %{ignore_land_protector: true}
  end

  test "skips impacts scheduled onto land protector cells" do
    :ok =
      Storage.insert(
        group(
          group_id: 99,
          skill_id: 288,
          skill_name: :sa_landprotector,
          cells: [{151, 149}],
          expires_at: 10_000,
          state: %{land_protector: true}
        )
      )

    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
    stub(Combat, :splash_targets, fn @map_name, {148, 148}, 3, @caster_id -> [{:mob, 2001}] end)

    expect(Combat, :apply_skill_unit_damage, fn
      %{unit_id: @caster_id}, :mob, 2001, 83, 1, :fire, 125 -> :ok
    end)

    stub(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_stun, _params -> :ok end)

    group =
      group(
        state: %{
          meteor_schedule: [
            %{at: 700, position: {151, 149}},
            %{at: 700, position: {148, 148}}
          ]
        }
      )

    assert {:ok, %Group{state: %{meteor_schedule: []}}} = WzMeteor.on_interval(group, 700)
  end

  test "uses the exact Renewal HitCount table for each level" do
    for {count, level} <- Enum.with_index([2, 3, 3, 4, 4, 5, 5, 6, 6, 7], 1) do
      assert {:ok, %Group{state: %{meteor_schedule: schedule}}} =
               WzMeteor.schedule(group(level: level), fn _upper -> 0 end)

      assert length(schedule) == count
    end
  end

  test "the manager owns a deterministic schedule of random Meteor impacts" do
    stub(Catalog, :ground_module_for, fn :wz_meteor -> {:ok, WzMeteor} end)
    manager = start_manager(rng: fn upper -> upper - 1 end)

    assert :ok = Manager.register(manager, group(expires_at: 2_000, next_tick_at: 700))

    assert %Group{
             state: %{
               meteor_schedule: [
                 %{at: 700, position: {153, 153}},
                 %{at: 1_700, position: {153, 153}}
               ]
             }
           } = Storage.get(1)
  end

  test "each due impact deals Fire damage and attempts level-scaled Stun after damage" do
    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
    stub(Combat, :splash_targets, fn @map_name, {151, 149}, 3, @caster_id -> [{:mob, 2001}] end)

    expect(Combat, :apply_skill_unit_damage, fn
      %{unit_id: @caster_id}, :mob, 2001, 83, 1, :fire, 125 -> :ok
    end)

    expect(StatusInterpreter, :apply_status, fn
      :mob, 2001, :sc_stun, [val1: 1, duration: 4_500, success_rate: 3] -> :ok
    end)

    group = group(state: %{meteor_schedule: [%{at: 700, position: {151, 149}}]})

    assert {:ok, %Group{state: %{meteor_schedule: []}}} = WzMeteor.on_interval(group, 700)
  end

  test "does not attempt Stun when an impact cannot damage its target" do
    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
    stub(Combat, :splash_targets, fn @map_name, {151, 149}, 3, @caster_id -> [{:mob, 2001}] end)

    stub(Combat, :apply_skill_unit_damage, fn _caster,
                                              _type,
                                              _id,
                                              _skill,
                                              _level,
                                              _element,
                                              _ratio ->
      :miss
    end)

    reject(&StatusInterpreter.apply_status/4)

    group = group(state: %{meteor_schedule: [%{at: 700, position: {151, 149}}]})

    assert {:ok, %Group{state: %{meteor_schedule: []}}} = WzMeteor.on_interval(group, 700)
  end

  test "late manager cadence applies every missed impact once without spawning meteor processes" do
    test_pid = self()
    stub(Catalog, :ground_module_for, fn :wz_meteor -> {:ok, WzMeteor} end)
    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

    stub(Combat, :splash_targets, fn @map_name, _position, 3, @caster_id -> [{:mob, 2001}] end)

    stub(Combat, :apply_skill_unit_damage, fn _caster, :mob, 2001, 83, 1, :fire, 125 ->
      send(test_pid, :impact)
      :ok
    end)

    stub(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_stun, _params -> :ok end)

    manager = start_manager(rng: fn _upper -> 0 end)
    assert :ok = Manager.register(manager, group(expires_at: 2_000, next_tick_at: 700))

    assert :ok = Manager.tick(manager, 1_700)
    assert_received :impact
    assert_received :impact
    refute_received :impact
    assert Process.alive?(manager)
    assert %Group{state: %{meteor_schedule: []}} = Storage.get(1)
  end

  test "skips impacts after caster loss while preserving the schedule through expiry" do
    stub(Catalog, :ground_module_for, fn :wz_meteor -> {:ok, WzMeteor} end)

    manager =
      start_manager(
        rng: fn _upper -> 0 end,
        unit_available?: fn _unit_type, _unit_id, _map_name -> false end
      )

    assert {:ok, placement} = WzMeteor.on_place(group([]))

    assert :ok =
             Manager.register(
               manager,
               group(
                 expires_at: 2_000,
                 next_tick_at: 700,
                 lifecycle_policy: placement.lifecycle_policy
               )
             )

    reject(&Combat.resolve_combatant/1)
    reject(&Combat.splash_targets/4)
    reject(&Combat.apply_skill_unit_damage/7)

    assert :ok = Manager.tick(manager, 700)

    assert %Group{
             next_tick_at: 1_700,
             lifecycle_policy: %LifecyclePolicy{on_caster_loss: :skip_action},
             state: %{meteor_schedule: [_first, _second]}
           } = Storage.get(1)
  end
end
