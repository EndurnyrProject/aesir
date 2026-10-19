defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanChaoticTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanChaotic
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "chaotic_order_map"

  setup :setup_ets_tables

  setup do
    owner = %PlayerState{character_id: 100, map_name: @map, x: 20, y: 20}
    :ok = UnitRegistry.register_unit(:player, 100, PlayerState, owner, self())
    :ok = SpatialIndex.add_unit(:player, 100, 20, 20, @map)
    :ok
  end

  test "the attacker roll indexes the owner's attackers in block order, newest first" do
    attacker_at(7_001, 21, 20)
    attacker_at(7_002, 22, 20)
    seed_rolls([{100, 100}, {2, 1}])

    assert {:local_effects, _, [{:mob, {:apply_heal, 7_002, _amount, _source}}]} =
             HvanChaotic.cast(vanilmirth(), :self, 5, HvanChaotic.definition())
  end

  test "only the first 30 attackers in block order can be picked" do
    for i <- 0..30, do: attacker_at(7_100 + i, 16 + rem(i, 8), 16 + div(i, 8))
    seed_rolls([{100, 100}, {30, 30}])

    assert {:local_effects, _, [{:mob, {:apply_heal, 7_101, _amount, _source}}]} =
             HvanChaotic.cast(vanilmirth(), :self, 5, HvanChaotic.definition())
  end

  defp attacker_at(id, x, y) do
    mob =
      %MobState{
        instance_id: id,
        mob_id: 1,
        mob_data: nil,
        spawn_ref: nil,
        sp: 0,
        x: x,
        y: y,
        map_name: @map,
        hp: 100,
        is_dead: false,
        target_ref: {:player, 100},
        attack_target: {:player, 100},
        spawned_at: 0
      }
      |> Aesir.TestMob.publish(max_sp: 0, max_hp: 100)

    pid = spawn_link(fn -> answer_state(mob) end)
    :ok = UnitRegistry.register_unit(:mob, id, MobState, mob, pid)
    :ok = SpatialIndex.add_unit(:mob, id, x, y, @map)
  end

  defp answer_state(mob) do
    receive do
      {:"$gen_call", from, :get_state} ->
        GenServer.reply(from, mob)
        answer_state(mob)
    end
  end

  defp seed_rolls(expected) do
    seed =
      Enum.find(1..100_000, fn seed ->
        :rand.seed(:exsss, {seed, seed + 1, seed + 2})
        Enum.all?(expected, fn {upper, roll} -> :rand.uniform(upper) == roll end)
      end)

    :rand.seed(:exsss, {seed, seed + 1, seed + 2})
  end

  defp vanilmirth do
    %HomunculusState{
      id: 1,
      owner_character_id: 100,
      owner_session_pid: self(),
      class_id: 6_004,
      name: "Vanilmirth",
      lifecycle: :active,
      level: 50,
      hp: 1_000,
      max_hp: 1_000,
      sp: 100,
      max_sp: 100,
      int: 50,
      world_gid: 1_500_001,
      map_name: @map,
      x: 10,
      y: 10,
      action_state: :idle,
      movement_state: :standing,
      combat_stats: %{matk: 7, matk_min: 7, matk_max: 7}
    }
  end
end
