defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmineTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtBlastmine
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

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
    test "is a Wind ground misc skill with range 3 and splash 1, registered in the catalog" do
      assert {:ok, HtBlastmine} = Catalog.ground_module_for(:ht_blastmine)
      d = HtBlastmine.definition()
      assert d.id == 122
      assert d.element == :wind
      assert d.damage_kind == :misc
      assert d.splash_radius == 1
      assert d.range == 3
    end
  end

  describe "on_place/1" do
    test "lays a 3x3 footprint and the placer-stamped base damage (no arming delay)" do
      stub(UnitRegistry, :get_unit_info, fn :player, @caster_id ->
        {:ok, %{stats: %{dex: 50, int: 40, base_level: 50}}}
      end)

      assert {:ok, placement} = HtBlastmine.on_place(group(%{}))

      assert length(placement.cells) == 9
      assert {50, 50} in placement.cells
      assert {49, 49} in placement.cells
      assert {51, 51} in placement.cells
      assert placement.visible? == false
      refute Map.has_key?(placement.state, :armed_at)
      # trunc(3 * 50 * (3.0 + 50/100) * (1.0 + 40/35)) = 1125
      assert placement.state.base_damage == 1125
      assert placement.state.armed == true
      assert placement.state.reclaimable == true
      assert placement.state.trap_item == 1065
    end
  end

  describe "on_touch/2" do
    test "splashes Wind misc damage on an enemy trigger (within variance) and expires" do
      stub(UnitRegistry, :get_unit, fn :player, @caster_id ->
        {:ok, {PlayerState, %PlayerState{character_id: @caster_id}, self()}}
      end)

      expect(Combat, :execute_misc_splash, fn caster, {50, 50}, 1, opts ->
        assert caster.character_id == @caster_id
        assert opts[:base_damage] >= 450 and opts[:base_damage] <= 545
        assert opts[:element] == :wind
        [2001]
      end)

      assert :expire = HtBlastmine.on_touch(group(%{base_damage: 500}), {:mob, 2001})
    end

    test "the owner does not trigger their own trap" do
      reject(&Combat.execute_misc_splash/4)

      assert {:ok, %Group{}} =
               HtBlastmine.on_touch(group(%{base_damage: 500}), {:player, @caster_id})
    end
  end
end
