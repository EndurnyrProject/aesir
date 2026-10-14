defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtClaymoretrapTest do
  use ExUnit.Case, async: false
  import Mimic
  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtClaymoretrap
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(SkillAttack)
    :ok
  end

  @caster_id 1000
  @cell {50, 50}
  @now 10_000

  defp group(state, attrs \\ []) do
    base = %Group{
      group_id: 1,
      skill_id: 123,
      skill_name: :ht_claymoretrap,
      level: 3,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: "prontera",
      center: {50, 50},
      cells: [{50, 50}],
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      state: state
    }

    struct(base, attrs)
  end

  defp armed,
    do:
      group(%{base_damage: 500, trap: armed_trap(claymore_spendable?: true)}, expires_at: 60_000)

  describe "registration & metadata" do
    @tag game_mode: :renewal
    test "is a Fire ground misc skill with range 3 and splash 2" do
      d = HtClaymoretrap.definition()
      assert d.element == :fire
      assert d.damage_kind == :misc
      assert d.splash_radius == 2
      assert d.range == 3
      assert d.sp_cost == List.duplicate(15, 5)
      assert d.item_cost == [%{id: 1065, amount: 2}]
      assert d.cast_time == List.duplicate(500, 5)
      assert HtClaymoretrap.definition(:pre_renewal).cast_time == []
      assert HtClaymoretrap.definition(:pre_renewal).after_cast_delay == []
      assert d.fixed_cast_time == List.duplicate(300, 5)
      assert d.after_cast_delay == List.duplicate(1_000, 5)
      assert d.unit_duration == [20_000, 40_000, 60_000, 80_000, 100_000]
    end
  end

  describe "on_place/1" do
    @tag game_mode: :renewal
    test "lays one visible trigger cell with placer-stamped damage" do
      stub(UnitRegistry, :get_unit_info, fn :player, @caster_id ->
        {:ok, %{stats: %{dex: 50, int: 40, base_level: 50}}}
      end)

      assert {:ok, placement} = HtClaymoretrap.on_place(group(%{}))

      assert placement.cells == [{50, 50}]
      assert placement.visibility == :public
      # trunc(3 * 50 * (3.0 + 50/100) * (1.0 + 40/35)) = 1125
      assert placement.state.base_damage == 1125

      assert %TrapState{
               phase: :armed,
               reclaim_item_id: 1065,
               claymore_spendable?: true,
               natural_expiry: :become_used,
               return_item_on_expiry?: false
             } = placement.state.trap

      assert placement.state.ignore_land_protector
    end
  end

  describe "detonation" do
    @tag game_mode: :renewal
    test "enemy contact applies one split Fire misc roll and requests self-used plus a spend command" do
      stub_units([player(@caster_id)])

      expect(SkillAttack, :execute_field_misc_splash, fn caster, {50, 50}, 2, %Group{}, opts ->
        assert caster.character_id == @caster_id
        assert opts[:base_damage] >= 450 and opts[:base_damage] <= 545
        assert opts[:element] == :fire
        assert opts[:split]
        [2001, 2002]
      end)

      assert {:ok, %Group{expires_at: 11_500, state: %{trap: %TrapState{phase: :used}}},
              [{:spend_traps, "prontera", {50, 50}, 2}]} =
               HtClaymoretrap.on_unit_hit(armed(), @cell, {:mob, 2001}, @now)
    end

    @tag game_mode: :pre_renewal
    test "a pre-renewal blast deals the full roll to every enemy" do
      stub_units([player(@caster_id)])

      expect(SkillAttack, :execute_field_misc_splash, fn _caster, {50, 50}, 2, %Group{}, opts ->
        assert opts[:base_damage] == 500
        refute opts[:split]
        [2001]
      end)

      assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}, [{:spend_traps, _, _, 2}]} =
               HtClaymoretrap.on_unit_hit(armed(), @cell, {:mob, 2001}, @now)
    end

    test "the owner does not trigger their own trap" do
      stub_units([player(@caster_id), mob(2001)])

      assert [{:mob, 2001}] =
               HtClaymoretrap.unit_targets(armed(), @cell, [{:player, @caster_id}, {:mob, 2001}])
    end

    test "an unavailable caster leaves the trap armed without damage or a spend command" do
      stub_units([])
      reject(&SkillAttack.execute_field_misc_splash/5)

      armed = armed()
      assert {:ok, ^armed} = HtClaymoretrap.on_unit_hit(armed, @cell, {:mob, 2001}, @now)
    end

    @tag game_mode: :pre_renewal
    test "a pre-renewal Claymore returns its trap item when its time runs out" do
      setup_ets_tables(%{})
      test_pid = self()

      stub(UnitRegistry, :get_unit_info, fn :player, @caster_id ->
        {:ok, %{stats: %{dex: 50, int: 40, base_level: 50}}}
      end)

      stub(Coordinator, :drop_items, fn map_name, items, x, y ->
        send(test_pid, {:dropped, map_name, items, x, y})
        :ok
      end)

      reject(&SkillAttack.execute_field_misc_splash/5)

      placed = group(%{cast_origin: :normal, paid_return?: true})
      assert {:ok, placement} = HtClaymoretrap.on_place(placed)

      manager =
        start_supervised!(
          {Manager,
           name: nil,
           clock: fn -> @now end,
           schedule_tick: fn _pid, _interval -> :ok end,
           unit_available?: fn _unit_type, _unit_id, _map_name -> true end}
        )

      allow(Coordinator, self(), manager)

      :ok =
        Manager.register(manager, %{
          placed
          | handler: HtClaymoretrap,
            visibility: placement.visibility,
            unit_range: placement.unit_range,
            expires_at: @now,
            state: placement.state
        })

      assert :ok = Manager.tick(manager, @now)

      assert_received {:dropped, "prontera", [{1065, 1, 50, 50, true}], 50, 50}
      assert nil == Storage.get(1)
    end
  end

  describe "Claymore-spendable trap matrix" do
    @stats %{dex: 10, int: 10, base_level: 10}

    test "the fixed eligible skill set is marked spendable" do
      for skill_name <- [
            :ht_landmine,
            :ht_blastmine,
            :ht_shockwave,
            :ht_flasher,
            :ht_sandman,
            :ht_freezingtrap,
            :ht_claymoretrap
          ] do
        eligible_group = %Group{
          group_id: 1,
          skill_name: skill_name,
          caster_id: @caster_id,
          caster_type: :player,
          state: %{}
        }

        state = Trap.place_state(1, @stats, eligible_group)
        assert state.trap.claymore_spendable?
      end
    end

    test "unrelated trap types are excluded" do
      for skill_name <- [:ht_skidtrap, :ht_anklesnare, :ht_talkiebox] do
        excluded_group = %Group{
          group_id: 1,
          skill_name: skill_name,
          caster_id: @caster_id,
          caster_type: :player,
          state: %{}
        }

        state = Trap.place_state(1, @stats, excluded_group)
        refute state.trap.claymore_spendable?
      end
    end
  end
end
