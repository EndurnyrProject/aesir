defmodule Aesir.ZoneServer.Script.DslUnitwarpTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context

  setup do
    test_pid = self()
    mob = build(:mob_state, instance_id: 5_000, map_name: "prontera", x: 10, y: 10)

    stub(UnitRegistry, :get_unit, fn
      :mob, 5_000 -> {:ok, {MobState, mob, test_pid}}
      _type, _id -> {:error, :not_found}
    end)

    stub(UnitRegistry, :get_char_id_by_account, fn _account -> {:error, :not_found} end)

    stub(MapCache, :get, fn
      map when map in ["prontera", "izlude"] -> {:ok, :map_data}
      _map -> {:error, :not_found}
    end)

    stub(MapFlags, :get, fn _map, _flag -> false end)
    stub(Cell, :traversable?, fn _map, _x, _y -> true end)
    # `CLR_OUTSIGHT`: the mob vanishes out of sight, not with the teleport effect.
    stub(MobSession, :warp, fn pid, map, x, y, 0 -> send(pid, {:mob_warp, map, x, y}) end)
    stub(PlayerSession, :warp, fn pid, map, x, y -> send(pid, {:player_warp, map, x, y}) end)

    stub(PlayerSession, :script_apply, fn _pid, op ->
      send(test_pid, {:script_apply, op})
      {:ok, build(:player_state)}
    end)

    detached = %Ctx{
      char_id: nil,
      account_id: nil,
      connection_pid: nil,
      game_state: nil,
      source: {:npc, :test_npc},
      attached_unit: {:mob, 5_000}
    }

    %{mob: mob, mob_ctx: detached, player_ctx: build(:script_ctx, session_pid: test_pid)}
  end

  describe "unit resolution" do
    test "id 0 is the attached monster", %{mob_ctx: ctx} do
      assert {_ctx, 0} = Dsl.unitwarp(ctx, 0, "this", 20, 21)
      assert_received {:mob_warp, "prontera", 20, 21}
    end

    test "id 0 is the attached player when no monster is attached", %{player_ctx: ctx} do
      assert {_ctx, 0} = Dsl.unitwarp(ctx, 0, "izlude", 20, 21)
      assert_received {:script_apply, {:warp, "izlude", 20, 21}}
    end

    test "a nonzero id names a monster instance", %{player_ctx: ctx} do
      assert {_ctx, 0} = Dsl.unitwarp(ctx, 5_000, "prontera", 20, 21)
      assert_received {:mob_warp, "prontera", 20, 21}
    end

    test "the attached player's account id is the attached player", %{player_ctx: ctx} do
      assert {_ctx, 0} = Dsl.unitwarp(ctx, ctx.account_id, "this", 20, 21)
      assert_received {:script_apply, {:warp, "prontera", 20, 21}}
    end

    test "another online player's account id casts the warp to their session",
         %{player_ctx: ctx} do
      other = build(:player_state, account_id: 777)
      stub(UnitRegistry, :get_char_id_by_account, fn 777 -> {:ok, other.character_id} end)

      stub(UnitRegistry, :get_unit, fn
        :player, id when id == other.character_id -> {:ok, {PlayerState, other, self()}}
        :mob, _id -> {:error, :not_found}
      end)

      assert {_ctx, 0} = Dsl.unitwarp(ctx, 777, "izlude", 20, 21)
      assert_received {:player_warp, "izlude", 20, 21}
    end

    test "a unit that is not found fails the command and returns 0", %{mob_ctx: ctx} do
      assert {%Ctx{status: :ok, failures: [{:unitwarp, :unit_not_found}]}, 0} =
               Dsl.unitwarp(%{ctx | attached_unit: nil}, 0, "this", 20, 21)

      assert {%Ctx{failures: [{:unitwarp, :unit_not_found}]}, 0} =
               Dsl.unitwarp(ctx, 4_242, "this", 20, 21)
    end

    test "a map that is not loaded fails the command and returns 0", %{mob_ctx: ctx} do
      assert {%Ctx{failures: [{:unitwarp, :unknown_map}]}, 0} =
               Dsl.unitwarp(ctx, 0, "nowhere", 20, 21)

      refute_received {:mob_warp, _map, _x, _y}
    end
  end

  describe "unit_warp results" do
    test "a dead monster returns 1", %{mob_ctx: ctx, mob: mob} do
      stub(UnitRegistry, :get_unit, fn :mob, 5_000 ->
        {:ok, {MobState, %{mob | is_dead: true}, self()}}
      end)

      assert {_ctx, 1} = Dsl.unitwarp(ctx, 0, "this", 20, 21)
      refute_received {:mob_warp, _map, _x, _y}
    end

    test "monster_noteleport refuses a monster that is not a slave", %{mob_ctx: ctx, mob: mob} do
      stub(MapFlags, :get, fn "prontera", :monster_noteleport -> true end)

      assert {_ctx, 1} = Dsl.unitwarp(ctx, 0, "this", 20, 21)
      refute_received {:mob_warp, _map, _x, _y}

      stub(UnitRegistry, :get_unit, fn :mob, 5_000 ->
        {:ok, {MobState, %{mob | master_id: 9}, self()}}
      end)

      assert {_ctx, 0} = Dsl.unitwarp(ctx, 0, "this", 20, 21)
      assert_received {:mob_warp, "prontera", 20, 21}
    end

    test "noteleport on the player's map returns 1", %{player_ctx: ctx} do
      stub(MapFlags, :get, fn "prontera", :noteleport -> true end)

      assert {_ctx, 1} = Dsl.unitwarp(ctx, 0, "izlude", 20, 21)
      refute_received {:script_apply, _op}
    end

    test "a monster warp to another map fails with 1", %{mob_ctx: ctx} do
      assert {%Ctx{failures: [{:unitwarp, :cross_map_mob_warp_unsupported}]}, 1} =
               Dsl.unitwarp(ctx, 0, "izlude", 20, 21)
    end

    test "a refused warp of the attached player returns 1", %{player_ctx: ctx} do
      stub(PlayerSession, :script_apply, fn _pid, _op -> {:error, :warp_refused} end)

      assert {%Ctx{failures: [{:warp, :warp_refused}]}, 1} =
               Dsl.unitwarp(ctx, 0, "izlude", 20, 21)
    end

    test "a negative coordinate picks a random map cell, 2 when none is found",
         %{mob_ctx: ctx} do
      stub(Cell, :random_traversable_inland, fn "prontera" -> {:ok, {40, 41}} end)
      assert {_ctx, 0} = Dsl.unitwarp(ctx, 0, "this", -1, 21)
      assert_received {:mob_warp, "prontera", 40, 41}

      stub(Cell, :random_traversable_inland, fn "prontera" -> :error end)
      assert {_ctx, 2} = Dsl.unitwarp(ctx, 0, "this", 20, -1)
      refute_received {:mob_warp, _map, _x, _y}
    end

    test "an unwalkable cell takes a cell within 4 of it, 2 when none is found",
         %{mob_ctx: ctx} do
      stub(Cell, :traversable?, fn "prontera", 20, 21 -> false end)
      stub(Cell, :random_traversable_near, fn "prontera", {20, 21}, 4 -> {23, 18} end)
      assert {_ctx, 0} = Dsl.unitwarp(ctx, 0, "this", 20, 21)
      assert_received {:mob_warp, "prontera", 23, 18}

      stub(Cell, :random_traversable_near, fn "prontera", center, 4 -> center end)
      assert {_ctx, 2} = Dsl.unitwarp(ctx, 0, "this", 20, 21)
      refute_received {:mob_warp, _map, _x, _y}
    end
  end
end
