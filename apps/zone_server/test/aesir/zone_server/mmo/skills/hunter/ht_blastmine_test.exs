defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmineTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmine
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(SkillAttack)
    :ok
  end

  @caster_id 1000

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

  describe "registration & metadata" do
    @tag game_mode: :renewal
    test "is a Wind ground misc skill with range 3 and splash 1, registered in the catalog" do
      assert {:ok, HtBlastmine} = Catalog.ground_module_for(:ht_blastmine)
      d = HtBlastmine.definition()
      assert d.id == 122
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
    test "enemy contact applies one split Wind misc roll and requests the used transition" do
      caster = %PlayerState{character_id: @caster_id, map_name: "prontera"}
      target = %{instance_id: 2001, map_name: "prontera", hp: 100}

      stub(UnitRegistry, :get_unit, fn
        :player, @caster_id -> {:ok, {PlayerState, caster, self()}}
        :mob, 2001 -> {:ok, {Map, target, self()}}
      end)

      expect(SkillAttack, :execute_field_misc_splash, fn caster, {50, 50}, 1, %Group{}, opts ->
        assert caster.character_id == @caster_id
        assert opts[:base_damage] >= 450 and opts[:base_damage] <= 545
        assert opts[:element] == :wind
        assert opts[:split]
        [2001]
      end)

      assert :expire = HtBlastmine.on_touch(group(%{base_damage: 500}), {:mob, 2001})
    end

    test "natural armed expiry applies the same one-roll split effect once" do
      caster = %PlayerState{character_id: @caster_id, map_name: "prontera"}

      stub(UnitRegistry, :get_unit, fn :player, @caster_id ->
        {:ok, {PlayerState, caster, self()}}
      end)

      expect(SkillAttack, :execute_field_misc_splash, 1, fn caster, {50, 50}, 1, %Group{}, opts ->
        assert caster.character_id == @caster_id
        assert opts[:base_damage] >= 450 and opts[:base_damage] <= 545
        assert opts[:element] == :wind
        assert opts[:split]
        [2001, 2002]
      end)

      assert :ok = HtBlastmine.on_natural_expiry(group(%{base_damage: 500}))
    end

    test "the owner does not trigger their own trap" do
      reject(&SkillAttack.execute_field_misc_splash/5)

      assert {:ok, %Group{}} =
               HtBlastmine.on_touch(group(%{base_damage: 500}), {:player, @caster_id})
    end
  end
end
