defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzMeteorTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Net.GroundSkill
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzMeteor
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(SplashTargets)
    :ok
  end

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

  defp meteor(meteor) do
    {:ok, placement} = WzMeteor.on_place(group(state: %{meteor: meteor}))

    group(
      state: Map.put(placement.state, :meteor, meteor),
      next_tick_at: placement.initial_delay,
      expires_at: placement.duration,
      unit_range: placement.unit_range,
      path_check: placement.path_check,
      lifecycle_policy: placement.lifecycle_policy,
      handler: WzMeteor
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

    Process.put({Manager, :server}, manager)
    manager
  end

  @tag game_mode: :renewal

  test "matches Renewal data" do
    definition = WzMeteor.definition()

    assert definition.target_type == :ground
    assert definition.damage_kind == :magic
    assert definition.element == :fire
    assert definition.range == 9
    assert definition.splash_radius == 3
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

  test "each meteor is its own silent single-cell unit falling in turn" do
    assert {:ok, placement} = WzMeteor.on_place(group(state: %{meteor: 3}))

    assert placement.cells == [@center]
    assert placement.state == %{falling: false, strike_on_expiry: true}
    assert placement.interval == 1_000
    assert placement.initial_delay == 2_000
    assert placement.duration == 3_000
    assert placement.unit_range == 3
    assert placement.path_check == true
    assert placement.announce == false
    assert placement.lifecycle_policy.on_caster_loss == :skip_action
    refute Map.has_key?(placement, :visibility)
  end

  test "the first interval shows the fall once and lands the meteor 700 ms later" do
    test_pid = self()

    stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, packet ->
      send(test_pid, packet)
      :ok
    end)

    group = group(level: 4, state: %{meteor: 2, falling: false, strike_on_expiry: true})

    assert {:ok, falling} = WzMeteor.on_interval(group, 1_000)
    assert falling.expires_at == 1_700
    assert falling.state.falling == true
    assert_received %GroundSkill{skill_id: 83, src_id: @caster_id, level: 4, x: 150, y: 150}

    assert {:ok, ^falling} = WzMeteor.on_interval(falling, 1_100)
    refute_received %GroundSkill{}
  end

  test "only a falling meteor picks targets, through the splash eligibility" do
    stub(Combat, :resolve_combatant, fn :player, @caster_id -> {:ok, %{unit_id: @caster_id}} end)

    stub(SplashTargets, :eligible, fn [{:mob, 2001}, {:mob, 2002}], %{unit_id: @caster_id} ->
      [{:mob, 2001}]
    end)

    refs = [{:mob, 2001}, {:mob, 2002}]

    assert [] == WzMeteor.unit_targets(group(state: %{falling: false}), @center, refs)
    assert [{:mob, 2001}] == WzMeteor.unit_targets(group(state: %{falling: true}), @center, refs)
  end

  @tag game_mode: :renewal
  test "each impact deals Fire damage in HitCount divisions and attempts level-scaled Stun" do
    stub(Combat, :resolve_combatant, fn :player, @caster_id -> {:ok, %{unit_id: @caster_id}} end)

    expect(Combat, :apply_skill_unit_damage, fn
      %{unit_id: @caster_id} = caster, :mob, 2001, 83, 1, :fire, 125, opts ->
        assert opts[:hit_divisions] == 2
        opts[:additional_effect].(caster, {:mob, 2001})
        :ok
    end)

    expect(StatusInterpreter, :apply_status, fn
      :mob,
      2001,
      :sc_stun,
      [val1: 1, duration: 4_500, success_rate: 3, caster_id: @caster_id, source_type: :player] ->
        :ok
    end)

    group = group(state: %{falling: true})

    assert {:ok, ^group} = WzMeteor.on_unit_hit(group, @center, {:mob, 2001}, 700)
  end

  test "does not attempt Stun when an impact cannot damage its target" do
    stub(Combat, :resolve_combatant, fn :player, @caster_id -> {:ok, %{unit_id: @caster_id}} end)

    stub(Combat, :apply_skill_unit_damage, fn _caster,
                                              _type,
                                              _id,
                                              _skill,
                                              _level,
                                              _element,
                                              _ratio,
                                              _opts ->
      :miss
    end)

    reject(&StatusInterpreter.apply_status/4)

    group = group(state: %{falling: true})

    assert {:ok, ^group} = WzMeteor.on_unit_hit(group, @center, {:mob, 2001}, 700)
  end

  test "cast places one unit per meteor in falling order and ignores a refused one" do
    test_pid = self()

    stub(Unit, :place, fn _caster, :wz_meteor, 3, {x, y}, [state: %{meteor: meteor}] ->
      send(test_pid, {:placed, meteor, {x, y}})
      if meteor == 1, do: {:error, :no_walkable_cells}, else: {:ok, group([])}
    end)

    caster = %{unit_id: @caster_id}

    assert {:ok, ^caster} =
             WzMeteor.cast(caster, {:ground, 150, 150}, 3, WzMeteor.definition())

    for meteor <- 1..3 do
      assert_received {:placed, ^meteor, {x, y}}
      assert x in 147..153 and y in 147..153
    end

    refute_received {:placed, _, _}
  end

  test "meteor cells scatter within 3 cells, 16 at level 11, one per meteor" do
    rolls = [0, 6, 3, 3]
    Process.put(:rolls, rolls)

    rng = fn 7 ->
      [roll | rest] = Process.get(:rolls)
      Process.put(:rolls, rest)
      roll
    end

    assert WzMeteor.meteor_cells({150, 150}, 1, rng) == [{147, 153}, {150, 150}]

    assert WzMeteor.meteor_cells({150, 150}, 11, fn 33 -> 32 end) ==
             List.duplicate({166, 166}, 10)

    assert WzMeteor.meteor_count(11) == 10
    assert WzMeteor.hits_per_meteor(11) == 15
    assert Enum.map(1..11, &WzMeteor.scatter/1) == List.duplicate(3, 10) ++ [16]
  end

  describe "on the real unit pass" do
    setup {Aesir.MimicMode, :global}

    setup do
      test_pid = self()

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
        send(test_pid, packet)
        :ok
      end)

      stub(Combat, :resolve_combatant, fn :player, @caster_id ->
        {:ok, %{unit_type: :player, unit_id: @caster_id}}
      end)

      stub(SplashTargets, :eligible, fn refs, _caster -> refs end)

      stub(Combat, :apply_skill_unit_damage, fn _caster, type, id, 83, _l, :fire, _r, _opts ->
        send(test_pid, {:impact, {type, id}})
        :ok
      end)

      :ok = SpatialIndex.add_unit(:mob, 2001, 150, 150, @map_name)
      :ok
    end

    test "a meteor falls on its interval and strikes only on the pass that finds it landed" do
      manager = start_manager([])
      :ok = Manager.register(manager, meteor(1))

      :ok = Manager.tick(manager, 0)
      assert_received %GroundSkill{skill_id: 83, x: 150, y: 150}
      assert %Group{expires_at: 700, state: %{falling: true}} = Storage.get(1)
      refute_received {:impact, _}

      :ok = Manager.tick(manager, 600)
      refute_received {:impact, _}

      :ok = Manager.tick(manager, 700)
      assert_received {:impact, {:mob, 2001}}
      refute_received {:impact, _}
      assert Storage.get(1) == nil
    end

    test "a meteor landing on Land Protector strikes nobody" do
      manager = start_manager([])
      :ok = Manager.register(manager, meteor(1))

      :ok =
        Storage.insert(
          group(
            group_id: 99,
            skill_id: 288,
            skill_name: :sa_landprotector,
            expires_at: 10_000,
            state: %{land_protector: true}
          )
        )

      :ok = Manager.tick(manager, 0)
      :ok = Manager.tick(manager, 700)

      refute_received {:impact, _}
      assert Storage.get(1) == nil
    end

    test "a meteor whose caster is gone never falls and ends at its full duration unstruck" do
      manager = start_manager(unit_available?: fn _type, _id, _map -> false end)
      :ok = Manager.register(manager, meteor(2))

      :ok = Manager.tick(manager, 1_000)
      :ok = Manager.tick(manager, 1_700)
      assert %Group{state: %{falling: false}} = Storage.get(1)

      :ok = Manager.tick(manager, 2_000)

      refute_received %GroundSkill{}
      refute_received {:impact, _}
      assert Storage.get(1) == nil
    end
  end

  @tag game_mode: :pre_renewal
  test "classic drops the same 2 to 7 meteors at 100 percent each with a 5 s stun" do
    assert Enum.map(1..10, &WzMeteor.meteor_count/1) == [2, 3, 3, 4, 4, 5, 5, 6, 6, 7]
    assert WzMeteor.skill_ratio() == 100
    assert WzMeteor.definition(:pre_renewal).unit_duration == List.duplicate(5_000, 10)
    assert WzMeteor.definition(:pre_renewal).cast_time == List.duplicate(15_000, 10)
    assert WzMeteor.definition(:pre_renewal).fixed_cast_time == []

    assert WzMeteor.definition(:pre_renewal).after_cast_delay == [
             2000,
             3000,
             3000,
             4000,
             4000,
             5000,
             5000,
             6000,
             6000,
             7000
           ]

    assert WzMeteor.definition(:pre_renewal).cooldown == []
  end

  @tag game_mode: :renewal
  test "renewal drops 2 to 7 meteors at 125 percent, each striking 2 to 7 times" do
    assert Enum.map(1..10, &WzMeteor.meteor_count/1) == [2, 3, 3, 4, 4, 5, 5, 6, 6, 7]
    assert Enum.map(1..10, &WzMeteor.hits_per_meteor/1) == [2, 3, 3, 4, 4, 5, 5, 6, 6, 7]
    assert WzMeteor.skill_ratio() == 125
  end

  @tag game_mode: :pre_renewal
  test "classic meteors strike 1 to 5 times each" do
    assert Enum.map(1..10, &WzMeteor.hits_per_meteor/1) == [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
  end
end
