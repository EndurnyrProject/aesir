defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfSoulburnFeedbackTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Skills.Professor.PfSoulburn
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Resource
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :set_mimic_private

  setup do
    Mimic.copy(Resource)
    Mimic.copy(MagicAttack)
    owner = self()

    stub(Combat, :resolve_combatant, fn
      3001 -> {:ok, %{unit_type: :player}}
      4001 -> {:ok, %{unit_type: :mob}}
    end)

    stub(Resource, :read, fn _, :sp -> {:ok, 40} end)
    stub(Resource, :drain_sp_percent, fn _, _ -> :ok end)
    stub(SpatialIndex, :get_unit_position, fn :player, 3001 -> {:ok, {20, 21, "test"}} end)

    stub(Broadcast, :to_in_range, fn map, x, y, _range, packet ->
      send(owner, {:broadcast, map, x, y, packet})
      :ok
    end)

    stub(MagicAttack, :execute_magic_attack, fn _, _, _ -> {:ok, {:player, 3001}} end)
    stub(MagicAttack, :execute_self_magic_attack, fn _, _ -> {:ok, {:player, 1001}} end)
    :ok
  end

  test "reports the affected unit for every level and both caster types" do
    player = %PlayerState{
      character_id: 1001,
      map_name: "test",
      x: 10,
      y: 11,
      stats: %{current_state: %{sp: 50}}
    }

    mob = %MobState{
      instance_id: 2001,
      mob_id: 1,
      mob_data: %{},
      spawn_ref: nil,
      x: 12,
      y: 13,
      map_name: "test",
      hp: 100,
      sp: 50,
      spawned_at: 0
    }

    for {caster, id, x, y} <- [{player, 1001, 10, 11}, {mob, 2001, 12, 13}],
        level <- 1..5,
        {roll, target, bx, by} <- [{1, 3001, 20, 21}, {100, id, x, y}] do
      assert {:ok, _} =
               PfSoulburn.cast(caster, {:unit, 3001}, level, PfSoulburn.definition(),
                 rng: fn 100 -> roll end
               )

      assert_received {:broadcast, "test", ^bx, ^by,
                       %SkillEffect{
                         skill_id: 375,
                         level: ^level,
                         src_id: ^id,
                         target_id: ^target,
                         result: 1
                       }}
    end
  end

  test "rejected targets produce no skill feedback" do
    caster = %PlayerState{character_id: 1001}

    assert {:error, :invalid_target} =
             PfSoulburn.cast(caster, {:unit, 4001}, 1, PfSoulburn.definition(),
               rng: fn 100 -> 1 end
             )

    refute_received {:broadcast, _, _, _, %SkillEffect{}}
  end
end
