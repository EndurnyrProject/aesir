defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzVermilionTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzVermilion
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(SplashTargets)
    :ok
  end

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
        visibility: :none,
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
    allow(SplashTargets, self(), manager)
    allow(StatusInterpreter, self(), manager)
    manager
  end

  describe "on_place/1" do
    @tag game_mode: :renewal
    test "creates the canonical 13x13 Wind field and timing" do
      assert {:ok, placement} = WzVermilion.on_place(group())

      assert length(placement.cells) == 169
      assert {144, 144} in placement.cells
      assert {156, 156} in placement.cells
      assert placement.interval == 1_250
      assert placement.initial_delay == 0
      assert placement.duration == 1_000
      assert placement.lifecycle_policy.on_caster_loss == :skip_action
    end

    @tag game_mode: :pre_renewal
    test "classic keeps the field alive for 4 seconds" do
      assert {:ok, placement} = WzVermilion.on_place(group())

      assert length(placement.cells) == 121
      assert placement.interval == 1_250
      assert placement.duration == 4_000
    end
  end

  describe "per-cell units" do
    @tag game_mode: :renewal
    test "renewal places 13x13 cells, each reaching one cell and sharing strikes" do
      assert {:ok, placement} = WzVermilion.on_place(group())
      assert length(placement.cells) == 169
      assert %{unit_range: 1, no_overlap: true, path_check: true} = placement
    end

    @tag game_mode: :pre_renewal
    test "classic places 11x11 cells" do
      assert {:ok, placement} = WzVermilion.on_place(group())
      assert length(placement.cells) == 121
      assert {145, 145} in placement.cells and {155, 155} in placement.cells
    end

    test "a level 11 monster field places 15x15 cells" do
      assert {:ok, placement} = WzVermilion.on_place(group(level: 11))
      assert length(placement.cells) == 225
    end
  end

  describe "definition/0" do
    @tag game_mode: :renewal
    test "matches the Renewal level tables" do
      definition = WzVermilion.definition()

      assert definition.max_level == 10
      assert definition.target_type == :ground
      assert definition.damage_kind == :magic
      assert definition.element == :wind
      assert definition.range == 9
      assert definition.splash_radius == 6
      assert definition.hit_interval == 1_250
      assert definition.hit_count == -20
      assert definition.unit_duration == List.duplicate(1_000, 10)
      assert definition.duration == List.duplicate(18_000, 10)
      assert definition.sp_cost == [60, 64, 68, 72, 76, 80, 84, 88, 92, 96]
      assert definition.cast_time == [6300, 6100, 5900, 5700, 5500, 5300, 5100, 4900, 4700, 4500]
      assert definition.fixed_cast_time == List.duplicate(1_500, 10)
      assert definition.after_cast_delay == List.duplicate(1_000, 10)
      assert definition.cooldown == List.duplicate(5_000, 10)
    end
  end

  describe "on_unit_hit/4" do
    @tag game_mode: :renewal
    test "hits each eligible target and delegates an independent resistance-aware Blind attempt" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

      expect(Combat, :apply_skill_unit_damage, 2, fn
        %{unit_id: @caster_id} = caster, unit_type, target_id, 85, 10, :wind, 1_400, opts
        when {unit_type, target_id} in [{:mob, 2001}, {:player, 2002}] ->
          assert opts[:hit_divisions] == -20
          opts[:additional_effect].(caster, {unit_type, target_id})
          :ok
      end)

      expect(StatusInterpreter, :apply_status, 2, fn
        unit_type,
        target_id,
        :sc_blind,
        [
          val1: 10,
          duration: 18_000,
          success_rate: 60,
          caster_id: @caster_id,
          source_type: :player
        ]
        when {unit_type, target_id} in [{:mob, 2001}, {:player, 2002}] ->
          :ok
      end)

      assert {:ok, %Group{}} = WzVermilion.on_unit_hit(group(), @center, {:mob, 2001}, 1_250)
      assert {:ok, %Group{}} = WzVermilion.on_unit_hit(group(), @center, {:player, 2002}, 1_250)
    end

    @tag game_mode: :renewal

    test "does not attempt Blind when the target is no longer valid for damage" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

      stub(Combat, :apply_skill_unit_damage, fn _caster,
                                                _type,
                                                _id,
                                                85,
                                                10,
                                                :wind,
                                                1_400,
                                                _opts ->
        {:error, :target_not_found}
      end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{}} = WzVermilion.on_unit_hit(group(), @center, {:mob, 2001}, 1_250)
    end
  end

  describe "manager cadence" do
    @tag game_mode: :renewal
    test "hits on the first manager cadence, continues every 1,250ms, then expires at 18s" do
      test_pid = self()
      stub(Catalog, :ground_module_for, fn :wz_vermilion -> {:ok, WzVermilion} end)
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

      stub(Combat, :apply_skill_unit_damage, fn _caster,
                                                :mob,
                                                2001,
                                                85,
                                                10,
                                                :wind,
                                                1_400,
                                                _opts ->
        send(test_pid, :hit)
        :ok
      end)

      stub(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_blind, _params -> :ok end)

      stub(SplashTargets, :eligible, fn refs, _caster -> refs end)
      SpatialIndex.add_unit(:mob, 2001, 150, 150, @map_name)
      manager = start_manager()

      :ok =
        Manager.register(
          manager,
          group(
            visibility: :public,
            unit_range: 1,
            cells: [@center],
            next_tick_at: 0,
            expires_at: 18_000
          )
        )

      assert :ok = Manager.tick(manager, 0)
      assert_received :hit

      assert :ok = Manager.tick(manager, 1_249)
      refute_received :hit

      for tick <- 1_250..17_500//1_250 do
        assert :ok = Manager.tick(manager, tick)
        assert_received :hit
      end

      assert %Group{} = Storage.get(1)

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
            visibility: :public,
            unit_range: 1,
            cells: [@center],
            next_tick_at: 1_250,
            expires_at: 18_000,
            lifecycle_policy: placement.lifecycle_policy
          )
        )

      stub(Combat, :resolve_combatant, fn @caster_id -> {:error, :target_not_found} end)
      SpatialIndex.add_unit(:mob, 2001, 150, 150, @map_name)
      reject(&Combat.splash_targets/4)
      reject(&Combat.apply_skill_unit_damage/8)
      reject(&StatusInterpreter.apply_status/4)

      assert :ok = Manager.tick(manager, 1_250)
      assert %Group{} = Storage.get(1)

      assert :ok = Manager.tick(manager, 18_000)
      assert Storage.get(1) == nil
    end
  end

  test "carries the classic data" do
    assert WzVermilion.definition(:pre_renewal).hit_count == -10
    assert WzVermilion.definition(:pre_renewal).unit_duration == List.duplicate(4_000, 10)
    assert WzVermilion.definition(:pre_renewal).duration == List.duplicate(30_000, 10)

    assert WzVermilion.definition(:pre_renewal).cast_time == [
             15_000,
             14_500,
             14_000,
             13_500,
             13_000,
             12_500,
             12_000,
             11_500,
             11_000,
             10_500
           ]

    assert WzVermilion.definition(:pre_renewal).fixed_cast_time == []
    assert WzVermilion.definition(:pre_renewal).after_cast_delay == List.duplicate(5000, 10)
    assert WzVermilion.definition(:pre_renewal).cooldown == []
  end

  @tag game_mode: :renewal
  test "renewal deals 400 plus 100 per level and blinds 10 plus 5 per level percent" do
    assert WzVermilion.skill_ratio(1) == 500
    assert WzVermilion.skill_ratio(1, false) == 100
    assert WzVermilion.blind_chance(10) == 60
  end

  @tag game_mode: :pre_renewal
  test "classic deals 80 plus 20 per level and blinds 4 per level percent up to 40" do
    assert WzVermilion.skill_ratio(1) == 100
    assert WzVermilion.skill_ratio(10) == 280
    assert WzVermilion.blind_chance(5) == 20
    assert WzVermilion.blind_chance(10) == 40
  end
end
