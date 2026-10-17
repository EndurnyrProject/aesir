defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.CastlingHandlerTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastlingHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "castling_order_map"
  @gid 1_500_001

  setup :setup_ets_tables

  test "redirects one attacker rolled among the owner's attackers in block order" do
    owner = owner_at({20, 20})
    attacker_at(7_001, 21, 20)
    attacker_at(7_002, 22, 20)
    seed_rolls([{2, 1}])

    CastlingHandler.redirect_attacker(owner, @gid)
    assert_receive {:redirected, 7_002, {:player, 100}, {:homunculus, @gid}}
    refute_receive {:redirected, _, _, _}, 50
  end

  test "rolls only among the first 30 attackers around the owner's cell" do
    owner = owner_at({20, 20})
    for i <- 0..30, do: attacker_at(7_100 + i, 16 + rem(i, 8), 16 + div(i, 8))
    attacker_at(7_200, 50, 50)
    seed_rolls([{30, 30}])

    CastlingHandler.redirect_attacker(owner, @gid)
    assert_receive {:redirected, 7_101, {:player, 100}, {:homunculus, @gid}}
    refute_receive {:redirected, _, _, _}, 50
  end

  test "attackers outside the owner's area are not counted" do
    owner = owner_at({20, 20})
    attacker_at(7_001, 21, 20)
    attacker_at(7_200, 50, 50)
    seed_rolls([{2, 2}])

    CastlingHandler.redirect_attacker(owner, @gid)
    assert_receive {:redirected, 7_001, {:player, 100}, {:homunculus, @gid}}
    refute_receive {:redirected, _, _, _}, 50
  end

  test "a failed redirect is not retried on another attacker" do
    owner = owner_at({20, 20})
    attacker_at(7_001, 21, 20, {:error, :target_changed})
    attacker_at(7_002, 22, 20, {:error, :target_changed})

    CastlingHandler.redirect_attacker(owner, @gid)
    assert_receive {:redirected, _id, _expected, _replacement}
    refute_receive {:redirected, _, _, _}, 50
  end

  defp owner_at({x, y}) do
    owner = %PlayerState{character_id: 100, map_name: @map, x: x, y: y}
    :ok = UnitRegistry.register_unit(:player, 100, PlayerState, owner, self())
    :ok = SpatialIndex.add_unit(:player, 100, x, y, @map)
    owner
  end

  defp attacker_at(id, x, y, reply \\ :ok) do
    mob = %MobState{
      instance_id: id,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      sp: 0,
      max_sp: 0,
      x: x,
      y: y,
      map_name: @map,
      hp: 100,
      max_hp: 100,
      is_dead: false,
      target_ref: {:player, 100},
      spawned_at: 0
    }

    test_pid = self()
    pid = spawn_link(fn -> answer(mob, test_pid, reply) end)
    :ok = UnitRegistry.register_unit(:mob, id, MobState, mob, pid)
    :ok = SpatialIndex.add_unit(:mob, id, x, y, @map)
  end

  defp answer(mob, test_pid, reply) do
    receive do
      {:"$gen_call", from, :get_state} ->
        GenServer.reply(from, mob)

      {:"$gen_call", from, {:ai, {:redirect_target, expected, replacement}}} ->
        send(test_pid, {:redirected, mob.instance_id, expected, replacement})
        GenServer.reply(from, reply)
    end

    answer(mob, test_pid, reply)
  end

  defp seed_rolls(expected) do
    seed =
      Enum.find(1..100_000, fn seed ->
        :rand.seed(:exsss, {seed, seed + 1, seed + 2})
        Enum.all?(expected, fn {upper, roll} -> :rand.uniform(upper) == roll end)
      end)

    :rand.seed(:exsss, {seed, seed + 1, seed + 2})
  end
end
