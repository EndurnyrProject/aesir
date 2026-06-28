defmodule Aesir.ZoneServer.Mmo.Skills.HtLandmineTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.HtLandmine
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 1000

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

  describe "registration & metadata" do
    test "is an Earth ground misc skill with range 3, registered in the catalog" do
      assert {:ok, HtLandmine} = Catalog.ground_module_for(:ht_landmine)
      d = HtLandmine.definition()
      assert d.id == 116
      assert d.element == :earth
      assert d.damage_kind == :misc
      assert d.target_type == :ground
      assert d.range == 3
    end
  end

  describe "on_place/1" do
    test "lays a single cell and the placer-stamped base damage (no arming delay)" do
      stub(UnitRegistry, :get_unit_info, fn :player, @caster_id ->
        {:ok, %{stats: %{dex: 50, int: 40, base_level: 50}}}
      end)

      assert {:ok, placement} = HtLandmine.on_place(group(%{}))

      assert placement.cells == [{50, 50}]
      refute Map.has_key?(placement.state, :armed_at)
      # trunc(3 * 50 * (3.0 + 50/100) * (1.0 + 40/35)) = trunc(150 * 3.5 * 2.142857) = 1125
      assert placement.state.base_damage == 1125
    end
  end

  describe "on_touch/2" do
    test "fires misc damage on an enemy mob (within the +/- variance band) and expires" do
      stub(UnitRegistry, :get_unit, fn :player, @caster_id ->
        {:ok, {PlayerState, %PlayerState{character_id: @caster_id}, self()}}
      end)

      expect(Combat, :execute_misc_attack, fn caster, 2001, opts ->
        assert caster.character_id == @caster_id
        # base 500 +/- variance (-10%..+9%): [450, 545]
        assert opts[:base_damage] >= 450 and opts[:base_damage] <= 545
        assert opts[:element] == :earth
        assert opts[:skill_level] == 3
        :ok
      end)

      assert :expire = HtLandmine.on_touch(group(%{base_damage: 500}), {:mob, 2001})
    end

    test "the owner does not trigger their own trap" do
      reject(&Combat.execute_misc_attack/3)

      assert {:ok, %Group{}} =
               HtLandmine.on_touch(group(%{base_damage: 500}), {:player, @caster_id})
    end

    test "an allied player does not trigger the trap" do
      reject(&Combat.execute_misc_attack/3)

      assert {:ok, %Group{}} = HtLandmine.on_touch(group(%{base_damage: 500}), {:player, 3000})
    end
  end
end
