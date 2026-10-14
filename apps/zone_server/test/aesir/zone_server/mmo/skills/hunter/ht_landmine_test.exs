defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtLandmineTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtLandmine
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
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
      skill_id: 116,
      skill_name: :ht_landmine,
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

  defp armed(attrs \\ []),
    do:
      group(%{base_damage: 500, trap: armed_trap()}, Keyword.merge([expires_at: 120_000], attrs))

  describe "registration & metadata" do
    @tag game_mode: :renewal
    test "is an Earth ground misc skill with range 3" do
      d = HtLandmine.definition()
      assert d.element == :earth
      assert d.damage_kind == :misc
      assert d.target_type == :ground
      assert d.range == 3
      assert d.sp_cost == List.duplicate(10, 5)
      assert d.item_cost == [%{id: 1065, amount: 1}]
      assert d.unit_duration == [200_000, 160_000, 120_000, 80_000, 40_000]
      assert d.cast_time == List.duplicate(500, 5)
      assert HtLandmine.definition(:pre_renewal).cast_time == []
      assert HtLandmine.definition(:pre_renewal).after_cast_delay == []
      assert d.fixed_cast_time == List.duplicate(300, 5)
      assert d.after_cast_delay == List.duplicate(1_000, 5)
    end
  end

  describe "on_place/1" do
    @tag game_mode: :renewal
    test "lays a single cell and the placer-stamped base damage (no arming delay)" do
      stub(UnitRegistry, :get_unit_info, fn :player, @caster_id ->
        {:ok, %{stats: %{dex: 50, int: 40, base_level: 50}}}
      end)

      assert {:ok, placement} = HtLandmine.on_place(group(%{}))

      assert placement.cells == [{50, 50}]
      assert placement.visibility == :party_only
      assert placement.duration == 120_000
      assert placement.state.ignore_land_protector
      refute Map.has_key?(placement.state, :armed_at)
      # trunc(3 * 50 * (3.0 + 50/100) * (1.0 + 40/35)) = trunc(150 * 3.5 * 2.142857) = 1125
      assert placement.state.base_damage == 1125

      assert %TrapState{
               phase: :armed,
               reclaim_item_id: 1065,
               claymore_spendable?: true,
               natural_expiry: :drop_item
             } = placement.state.trap
    end
  end

  describe "unit pass" do
    @tag game_mode: :renewal
    test "fires misc damage on an enemy mob (within the +/- variance band) and is spent" do
      stub_units([player(@caster_id), mob(2001)])

      expect(SkillAttack, :execute_field_misc_attack, fn caster, {:mob, 2001}, %Group{}, opts ->
        assert caster.character_id == @caster_id
        assert opts[:base_damage] >= 450 and opts[:base_damage] <= 545
        assert opts[:element] == :earth
        assert opts[:skill_level] == 3
        assert opts[:report_hit]
        {:ok, %{hit?: true}}
      end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_stun, params ->
        assert params[:source_id] == @caster_id
        assert params[:source_type] == :player
        assert params[:success_rate] == 10
        assert params[:duration] == 4_500
        :ok
      end)

      assert [{:mob, 2001}] = HtLandmine.unit_targets(armed(), @cell, [{:mob, 2001}])

      assert {:ok, %Group{expires_at: 11_500, state: %{trap: %TrapState{phase: :used}}}} =
               HtLandmine.on_unit_hit(armed(), @cell, {:mob, 2001}, @now)
    end

    @tag game_mode: :pre_renewal
    test "a pre-renewal blast stuns for 5 seconds" do
      stub_units([player(@caster_id)])

      stub(SkillAttack, :execute_field_misc_attack, fn _caster, {:mob, 2001}, %Group{}, opts ->
        assert opts[:base_damage] == 500
        {:ok, %{hit?: true}}
      end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_stun, params ->
        assert params[:duration] == 5_000
        :ok
      end)

      assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
               HtLandmine.on_unit_hit(armed(), @cell, {:mob, 2001}, @now)
    end

    test "a blast that deals nothing stuns nobody but still spends the mine" do
      stub_units([player(@caster_id)])

      stub(SkillAttack, :execute_field_misc_attack, fn _caster, {:mob, 2001}, %Group{}, _opts ->
        {:ok, %{hit?: false}}
      end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
               HtLandmine.on_unit_hit(armed(), @cell, {:mob, 2001}, @now)
    end

    test "failed damage delivery applies no Stun and still spends the mine" do
      stub_units([player(@caster_id)])

      for reason <- [:target_dead, :not_found, :failed_delivery] do
        expect(SkillAttack, :execute_field_misc_attack, fn _caster,
                                                           {:mob, 2001},
                                                           %Group{},
                                                           _opts ->
          {:error, reason}
        end)

        reject(&StatusInterpreter.apply_status/4)

        assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
                 HtLandmine.on_unit_hit(armed(), @cell, {:mob, 2001}, @now)
      end
    end

    test "the owner does not trigger their own trap" do
      stub_units([player(@caster_id), mob(2001)])

      assert [{:mob, 2001}] =
               HtLandmine.unit_targets(armed(), @cell, [{:player, @caster_id}, {:mob, 2001}])
    end

    test "an allied player does not trigger the trap" do
      stub_units([player(@caster_id), player(3000), mob(2001)])

      assert [{:mob, 2001}] =
               HtLandmine.unit_targets(armed(), @cell, [{:player, 3000}, {:mob, 2001}])
    end

    test "a mob-owned mine targets a player but not another mob" do
      mob_caster = mob(4000)
      stub_units([mob_caster, player(3000), mob(4001)])

      expect(SkillAttack, :execute_misc_attack, fn ^mob_caster, {:player, 3000}, _opts ->
        {:ok, %{hit?: true}}
      end)

      expect(StatusInterpreter, :apply_status, fn :player, 3000, :sc_stun, params ->
        assert params[:source_id] == 4000
        assert params[:source_type] == :mob
        :ok
      end)

      mob_group = armed(caster_type: :mob, caster_id: 4000)

      assert [{:player, 3000}] =
               HtLandmine.unit_targets(mob_group, @cell, [{:player, 3000}, {:mob, 4001}])

      assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
               HtLandmine.on_unit_hit(mob_group, @cell, {:player, 3000}, @now)
    end
  end

  @tag game_mode: :pre_renewal
  test "classic mines deal their stamped damage without variance" do
    assert Aesir.ZoneServer.Mmo.Skills.Hunter.Trap.roll_damage(500) == 500
  end
end
