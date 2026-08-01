defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtClaymoretrapTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtClaymoretrap
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 1000

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

  describe "registration & metadata" do
    test "is a Fire ground misc skill with range 3 and splash 2, registered in the catalog" do
      assert {:ok, HtClaymoretrap} = Catalog.ground_module_for(:ht_claymoretrap)
      d = HtClaymoretrap.definition()
      assert d.id == 123
      assert d.element == :fire
      assert d.damage_kind == :misc
      assert d.splash_radius == 2
      assert d.range == 3
      assert d.sp_cost == List.duplicate(15, 5)
      assert d.item_cost == [%{id: 1065, amount: 2}]
      assert d.cast_time == List.duplicate(500, 5)
      assert d.fixed_cast_time == List.duplicate(300, 5)
      assert d.after_cast_delay == List.duplicate(1_000, 5)
      assert d.unit_duration == [20_000, 40_000, 60_000, 80_000, 100_000]
    end
  end

  describe "on_place/1" do
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
    test "enemy contact applies one split Fire misc roll and requests self-used plus a spend command" do
      stub(UnitRegistry, :get_unit, fn :player, @caster_id ->
        {:ok, {PlayerState, %PlayerState{character_id: @caster_id}, self()}}
      end)

      expect(Combat, :execute_misc_splash, fn caster, {50, 50}, 2, opts ->
        assert caster.character_id == @caster_id
        assert opts[:base_damage] >= 450 and opts[:base_damage] <= 545
        assert opts[:element] == :fire
        assert opts[:split]
        [2001, 2002]
      end)

      assert {:expire, [{:spend_traps, "prontera", {50, 50}, 2}]} =
               HtClaymoretrap.on_touch(group(%{base_damage: 500}), {:mob, 2001})
    end

    test "the owner does not trigger their own trap" do
      reject(&Combat.execute_misc_splash/4)

      assert {:ok, %Group{}} =
               HtClaymoretrap.on_touch(group(%{base_damage: 500}), {:player, @caster_id})
    end

    test "an unavailable caster leaves the trap armed without damage or a spend command" do
      stub(UnitRegistry, :get_unit, fn :player, @caster_id -> {:error, :not_found} end)
      reject(&Combat.execute_misc_splash/4)

      assert {:ok, %Group{}} =
               HtClaymoretrap.on_touch(group(%{base_damage: 500}), {:mob, 2001})
    end

    test "natural armed expiry only transitions the trap itself, without damage or a spend command" do
      reject(&Combat.execute_misc_splash/4)
      reject(&UnitRegistry.get_unit/2)

      assert :ok = HtClaymoretrap.on_natural_expiry(group(%{base_damage: 500}))
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
