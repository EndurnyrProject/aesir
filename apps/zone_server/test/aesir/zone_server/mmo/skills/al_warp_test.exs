defmodule Aesir.ZoneServer.Mmo.Skills.AlWarpTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.AlWarp
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @caster_id 1000
  @dest {"prontera", 155, 180}

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp group(state, attrs \\ []) do
    base = %Group{
      group_id: 1,
      skill_id: 27,
      skill_name: :al_warp,
      level: 2,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: "prt_fild08",
      center: {100, 100},
      cells: [{100, 100}],
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      state: state
    }

    struct(base, attrs)
  end

  defp open_state(attrs \\ %{}) do
    Map.merge(%{dest: @dest, uses: 8, opens_at: now_ms() - 1}, attrs)
  end

  defp stub_target_session(player_id) do
    test_pid = self()

    stub(UnitRegistry, :get_unit, fn :player, ^player_id ->
      {:ok, {PlayerState, %PlayerState{character_id: player_id}, test_pid}}
    end)
  end

  describe "registration & metadata" do
    test "is a no-damage ground skill matching the rAthena table" do
      assert {:ok, AlWarp} = Catalog.ground_module_for(:al_warp)
      d = AlWarp.definition()
      assert d.id == 27
      assert d.max_level == 4
      assert d.target_type == :ground
      assert d.damage_type == :no_damage
      assert d.range == 9
      assert d.unit_duration == [10_000, 15_000, 20_000, 25_000]
      assert d.fixed_cast_time == [1_000, 1_000, 1_000, 1_000]
      assert d.after_cast_delay == [1_000, 1_000, 1_000, 1_000]
      assert d.sp_cost == [35, 32, 29, 26]
      assert d.item_cost == [%{id: 717, amount: 1}]
    end
  end

  describe "on_place/1" do
    test "stamps the caster's save point, level + 6 uses, and the 2s opening delay" do
      stub(UnitRegistry, :get_unit, fn :player, @caster_id ->
        {:ok,
         {PlayerState,
          %PlayerState{character_id: @caster_id, save_map: "prontera", save_x: 155, save_y: 180},
          self()}}
      end)

      before = now_ms()
      assert {:ok, placement} = AlWarp.on_place(group(%{}))

      assert placement.cells == [{100, 100}]
      assert placement.state.dest == @dest
      assert placement.state.uses == 8
      assert placement.state.opens_at >= before + 2_000
      assert placement.state.opens_at <= now_ms() + 2_000
      # 2s opening phase + Duration1 for level 2
      assert placement.duration == 2_000 + 15_000
      assert placement.lifecycle_policy.max_instances_per_caster == 3
    end
  end

  describe "on_touch/2" do
    test "warps a player through their session and spends one use" do
      stub_target_session(3000)

      assert {:ok, %Group{state: %{uses: 7}}} =
               AlWarp.on_touch(group(open_state()), {:player, 3000})

      assert_received {:"$gen_cast", {:warp, "prontera", 155, 180}}
    end

    test "expires when the last use is spent" do
      stub_target_session(3000)

      assert :expire = AlWarp.on_touch(group(open_state(%{uses: 1})), {:player, 3000})
      assert_received {:"$gen_cast", {:warp, "prontera", 155, 180}}
    end

    test "ignores touches before the portal opens" do
      reject(&UnitRegistry.get_unit/2)

      state = open_state(%{opens_at: now_ms() + 10_000})
      assert {:ok, %Group{state: %{uses: 8}}} = AlWarp.on_touch(group(state), {:player, 3000})
      refute_received {:"$gen_cast", _}
    end

    test "does not warp mobs" do
      reject(&UnitRegistry.get_unit/2)

      assert {:ok, %Group{state: %{uses: 8}}} =
               AlWarp.on_touch(group(open_state()), {:mob, 5000})
    end

    test "spends nothing when the player's session is gone" do
      stub(UnitRegistry, :get_unit, fn :player, 3000 -> {:error, :not_found} end)

      assert {:ok, %Group{state: %{uses: 8}}} =
               AlWarp.on_touch(group(open_state()), {:player, 3000})
    end
  end

  describe "on_interval/2" do
    test "warps players standing on the portal cell once it opens" do
      stub_target_session(3000)

      stub(SpatialIndex, :get_all_units_in_range, fn "prt_fild08", 100, 100, 0 ->
        [{:player, 3000}, {:mob, 5000}]
      end)

      assert {:ok, %Group{state: %{uses: 7}}} =
               AlWarp.on_interval(group(open_state()), now_ms())

      assert_received {:"$gen_cast", {:warp, "prontera", 155, 180}}
    end

    test "expires when standing occupants drain the last use" do
      stub_target_session(3000)

      stub(SpatialIndex, :get_all_units_in_range, fn _, _, _, _ -> [{:player, 3000}] end)

      assert {:expire, %Group{state: %{uses: 0}}} =
               AlWarp.on_interval(group(open_state(%{uses: 1})), now_ms())
    end

    test "does nothing before the portal opens" do
      reject(&SpatialIndex.get_all_units_in_range/4)

      state = open_state(%{opens_at: now_ms() + 10_000})
      assert {:ok, %Group{state: %{uses: 8}}} = AlWarp.on_interval(group(state), now_ms())
    end
  end
end
