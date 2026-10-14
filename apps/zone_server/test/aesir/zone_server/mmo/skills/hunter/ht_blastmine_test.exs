defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmineTest do
  use ExUnit.Case, async: false
  import Mimic
  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmine
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
      skill_id: 122,
      skill_name: :ht_blastmine,
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
    do: group(%{base_damage: 500, trap: armed_trap()}, expires_at: 25_000)

  describe "registration & metadata" do
    @tag game_mode: :renewal
    test "is a Wind ground misc skill with range 3 and splash 1" do
      d = HtBlastmine.definition()
      assert d.element == :wind
      assert d.damage_kind == :misc
      assert d.splash_radius == 1
      assert d.range == 3
      assert d.sp_cost == List.duplicate(10, 5)
      assert d.item_cost == [%{id: 1065, amount: 2}]
      assert HtBlastmine.definition(:pre_renewal).item_cost == [%{id: 1065, amount: 1}]
      assert d.cast_time == List.duplicate(500, 5)
      assert HtBlastmine.definition(:pre_renewal).cast_time == []
      assert HtBlastmine.definition(:pre_renewal).after_cast_delay == []
      assert d.fixed_cast_time == List.duplicate(300, 5)
      assert d.after_cast_delay == List.duplicate(1_000, 5)
      assert d.unit_duration == [25_000, 20_000, 15_000, 10_000, 5_000]
    end
  end

  describe "on_place/1" do
    @tag game_mode: :renewal
    test "lays one visible trigger cell with placer-stamped damage" do
      stub(UnitRegistry, :get_unit_info, fn :player, @caster_id ->
        {:ok, %{stats: %{dex: 50, int: 40, base_level: 50}}}
      end)

      assert {:ok, placement} = HtBlastmine.on_place(group(%{}))

      assert placement.cells == [{50, 50}]
      assert placement.visibility == :public
      refute Map.has_key?(placement.state, :armed_at)
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
    test "enemy contact applies one split Wind misc roll and springs the mine" do
      stub_units([player(@caster_id)])

      expect(SkillAttack, :execute_field_misc_splash, fn caster, {50, 50}, 1, %Group{}, opts ->
        assert caster.character_id == @caster_id
        assert opts[:base_damage] >= 450 and opts[:base_damage] <= 545
        assert opts[:element] == :wind
        assert opts[:split]
        [2001]
      end)

      assert {:ok, %Group{expires_at: 11_500, state: %{trap: %TrapState{phase: :used}}}} =
               HtBlastmine.on_unit_hit(armed(), @cell, {:mob, 2001}, @now)
    end

    @tag game_mode: :pre_renewal
    test "a pre-renewal blast deals the full roll to every enemy" do
      stub_units([player(@caster_id)])

      expect(SkillAttack, :execute_field_misc_splash, fn _caster, {50, 50}, 1, %Group{}, opts ->
        assert opts[:base_damage] == 500
        refute opts[:split]
        [2001]
      end)

      assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
               HtBlastmine.on_unit_hit(armed(), @cell, {:mob, 2001}, @now)
    end

    test "the owner does not trigger their own trap" do
      stub_units([player(@caster_id), mob(2001)])

      assert [{:mob, 2001}] =
               HtBlastmine.unit_targets(armed(), @cell, [{:player, @caster_id}, {:mob, 2001}])
    end
  end

  # The manager runs the expiry in its own process, so the stubs go global.
  describe "natural expiry" do
    setup {Aesir.MimicMode, :global}

    test "natural expiry turns the armed mine into a used trap without damage" do
      setup_ets_tables(%{})
      test_pid = self()
      stub_units([player(@caster_id), mob(2001)])

      stub(SkillAttack, :execute_field_misc_splash, fn _caster, _center, _radius, _group, _opts ->
        send(test_pid, :detonated)
        []
      end)

      manager =
        start_supervised!(
          {Manager,
           name: nil,
           clock: fn -> @now end,
           schedule_tick: fn _pid, _interval -> :ok end,
           unit_available?: fn _unit_type, _unit_id, _map_name -> true end}
        )

      trap = armed_trap(natural_expiry: :become_used)

      :ok =
        Manager.register(
          manager,
          group(%{base_damage: 500, trap: trap},
            handler: HtBlastmine,
            visibility: :public,
            unit_range: 1,
            expires_at: @now
          )
        )

      assert :ok = Manager.tick(manager, @now)

      assert %Group{expires_at: 11_500, state: %{trap: %TrapState{phase: :used}}} =
               Storage.get(1)

      refute_received :detonated
    end
  end
end
