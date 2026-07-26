defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtTalkieboxTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Net.ChatMessage
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit, as: SkillUnit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtTalkiebox
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 1000

  defp trap(phase \\ :armed) do
    {:ok, trap} =
      TrapState.new(%{
        phase: phase,
        reclaim_item_id: 1065,
        claymore_spendable?: false,
        natural_expiry: :drop_item,
        return_item_on_expiry?: true
      })

    trap
  end

  defp group(state, attrs \\ []) do
    base = %Group{
      group_id: 1,
      skill_id: 125,
      skill_name: :ht_talkiebox,
      level: 1,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: "prontera",
      center: {50, 50},
      cells: [{50, 50}],
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      visible?: false,
      state: state
    }

    struct(base, attrs)
  end

  describe "registration & metadata" do
    test "is a level-1 range-3 no-damage ground skill, registered in the catalog" do
      assert {:ok, HtTalkiebox} = Catalog.ground_module_for(:ht_talkiebox)
      d = HtTalkiebox.definition()
      assert d.id == 125
      assert d.max_level == 1
      assert d.target_type == :ground
      assert d.damage_type == :no_damage
      assert d.range == 3
      assert d.sp_cost == [1]
      assert d.item_cost == [%{id: 1065, amount: 1}]
      assert d.unit_duration == [600_000]
      assert d.hit_interval == 1_000
    end
  end

  describe "cast/4" do
    test "always requires the staged text-input reply" do
      caster = %PlayerState{character_id: @caster_id}

      assert {:error, :skill_input_required} =
               HtTalkiebox.cast(caster, {:ground, 50, 50}, 1, HtTalkiebox.definition())

      assert {:error, :skill_input_required} =
               HtTalkiebox.cast(caster, :self, 1, HtTalkiebox.definition())

      mob_caster = %{instance_id: 4000}

      assert {:error, :skill_input_required} =
               HtTalkiebox.cast(mob_caster, {:ground, 50, 50}, 1, HtTalkiebox.definition())
    end

    test "cast_with_origin delegates to cast/4 regardless of origin (item/auto/mob/direct)" do
      caster = %PlayerState{character_id: @caster_id}
      definition = HtTalkiebox.definition()

      for origin <- [:direct, :item, :auto, :mob, :normal] do
        assert {:error, :skill_input_required} =
                 HtTalkiebox.cast_with_origin(caster, {:ground, 50, 50}, 1, definition, origin)
      end
    end
  end

  describe "cast_with_input/5" do
    test "places the group with the validated text stamped atomically into its state" do
      caster = %PlayerState{character_id: @caster_id, map_name: "prontera", x: 50, y: 50}
      definition = HtTalkiebox.definition()

      expect(SkillUnit, :place, fn ^caster, :ht_talkiebox, 1, {50, 50}, opts ->
        assert opts[:origin] == :normal
        assert opts[:state] == %{paid_return?: true, message: "hello there"}
        {:ok, %Group{group_id: 1, skill_name: :ht_talkiebox}}
      end)

      assert {:ok, ^caster} =
               HtTalkiebox.cast_with_input(
                 caster,
                 {:ground, 50, 50},
                 1,
                 definition,
                 "hello there"
               )
    end

    test "propagates a placement failure" do
      caster = %PlayerState{character_id: @caster_id, map_name: "prontera", x: 50, y: 50}
      definition = HtTalkiebox.definition()

      expect(SkillUnit, :place, fn ^caster, :ht_talkiebox, 1, {50, 50}, _opts ->
        {:error, :no_walkable_cells}
      end)

      assert {:error, :no_walkable_cells} =
               HtTalkiebox.cast_with_input(caster, {:ground, 50, 50}, 1, definition, "hi")
    end

    test "rejects a non-ground target" do
      caster = %PlayerState{character_id: @caster_id}
      definition = HtTalkiebox.definition()

      assert {:error, :invalid_target} =
               HtTalkiebox.cast_with_input(caster, :self, 1, definition, "hi")
    end
  end

  describe "on_place/1" do
    test "arms a single hidden cell with a non-claymore-spendable trap" do
      stub(UnitRegistry, :get_unit_info, fn :player, @caster_id ->
        {:ok, %{stats: %{dex: 50, int: 40, base_level: 50}}}
      end)

      assert {:ok, placement} = HtTalkiebox.on_place(group(%{}))

      assert placement.cells == [{50, 50}]
      assert placement.visible? == false
      assert placement.duration == 600_000
      assert placement.interval == 1_000

      assert %TrapState{
               phase: :armed,
               reclaim_item_id: 1065,
               claymore_spendable?: false,
               natural_expiry: :drop_item
             } = placement.state.trap
    end
  end

  describe "on_touch/2" do
    test "a non-owner player activates the trap: visible, used, expires in five seconds" do
      before = System.monotonic_time(:millisecond)

      assert {:ok, %Group{} = updated} =
               HtTalkiebox.on_touch(group(%{trap: trap(), message: "hi"}), {:player, 2000})

      assert updated.visible? == true
      assert updated.state.trap.phase == :used
      assert updated.expires_at >= before + 5_000
      assert updated.expires_at <= System.monotonic_time(:millisecond) + 5_000
      assert updated.state.message == "hi"
    end

    test "the owner does not trigger their own trap" do
      armed = group(%{trap: trap(), message: "hi"})
      assert {:ok, ^armed} = HtTalkiebox.on_touch(armed, {:player, @caster_id})
    end

    test "a mob mover does not trigger the trap" do
      armed = group(%{trap: trap(), message: "hi"})
      assert {:ok, ^armed} = HtTalkiebox.on_touch(armed, {:mob, 2000})
    end

    test "an already-used trap ignores further touches" do
      used = group(%{trap: trap(:used), message: nil}, visible?: true)
      assert {:ok, ^used} = HtTalkiebox.on_touch(used, {:player, 2000})
    end
  end

  describe "on_interval/2" do
    test "once activated and materialized, announces the message on the cell's id" do
      used_group = group(%{trap: trap(:used), message: "hello there"}, visible?: true)

      stub(Storage, :get_cells_by_group, fn 1 ->
        [%Cell{cell_id: 777, group_id: 1, map_name: "prontera", x: 50, y: 50}]
      end)

      expect(Broadcast, :to_in_range, fn "prontera", 50, 50, _range, packet ->
        assert %ChatMessage{gid: 777, message: "hello there"} = packet
        :ok
      end)

      assert {:ok, %Group{} = updated} = HtTalkiebox.on_interval(used_group, 0)
      assert updated.state.message == nil
    end

    test "defers the announcement until the used cell is materialized" do
      used_group = group(%{trap: trap(:used), message: "hello there"}, visible?: true)

      stub(Storage, :get_cells_by_group, fn 1 -> [] end)
      reject(&Broadcast.to_in_range/5)

      assert {:ok, ^used_group} = HtTalkiebox.on_interval(used_group, 0)
    end

    test "an untouched armed trap is a no-op tick" do
      armed = group(%{trap: trap(), message: nil})
      reject(&Storage.get_cells_by_group/1)
      reject(&Broadcast.to_in_range/5)

      assert {:ok, ^armed} = HtTalkiebox.on_interval(armed, 0)
    end

    test "a used trap with no pending message is a no-op tick" do
      used_group = group(%{trap: trap(:used), message: nil}, visible?: true)
      reject(&Storage.get_cells_by_group/1)
      reject(&Broadcast.to_in_range/5)

      assert {:ok, ^used_group} = HtTalkiebox.on_interval(used_group, 0)
    end
  end
end
