defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtHomunculusTrapsTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.ZoneServer.TrapTestHelper

  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFlasher
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFreezingtrap
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtLandmine
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtShockwave
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Resource
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :verify_on_exit!

  setup do
    Mimic.copy(SkillAttack)
    Mimic.copy(Trap)
    Mimic.copy(Resource)
    :ok
  end

  @gid 1_500_001
  @cell {50, 50}
  @now 10_000
  @caster %MobState{
            instance_id: 1000,
            mob_id: 1002,
            mob_data:
              Aesir.TestMob.definition(
                element: {:neutral, 1},
                race: :formless,
                modes: [],
                attack_motion: 500
              ),
            spawn_ref: nil,
            map_name: "trap_hom",
            x: 50,
            y: 50,
            hp: 100,
            sp: 10,
            spawned_at: 0
          }
          |> Aesir.TestMob.publish(max_hp: 100, max_sp: 10)

  test "mob Land Mine uses the real hostile relation for Homunculus damage and Stun" do
    stub_units([mob(1000), homunculus(@gid, 3000)])
    mine = group(116, :ht_landmine, %{base_damage: 500})
    assert [{:homunculus, @gid}] = HtLandmine.unit_targets(mine, @cell, [{:homunculus, @gid}])

    stub(Trap, :resolve_caster, fn _group -> {:ok, @caster} end)
    stub(Trap, :roll_damage, fn 500 -> 500 end)

    expect(SkillAttack, :execute_misc_attack, fn @caster, {:homunculus, @gid}, opts ->
      assert opts[:skill_id] == 116
      {:ok, %{hit?: true}}
    end)

    expect(StatusInterpreter, :apply_status, fn :homunculus, @gid, :sc_stun, opts ->
      assert opts[:source_type] == :mob
      :ok
    end)

    assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
             HtLandmine.on_unit_hit(mine, @cell, {:homunculus, @gid}, @now)
  end

  test "mob Freezing Trap retains the exact typed connected Homunculus" do
    stub(Trap, :resolve_caster, fn _group -> {:ok, @caster} end)

    stub(SpatialIndex, :get_unit_position, fn :homunculus, @gid -> {:ok, {51, 50, "trap_hom"}} end)

    expect(SkillAttack, :execute_splash_attack, fn @caster, {51, 50}, 1, opts ->
      assert opts[:typed_results]
      [{:homunculus, @gid}]
    end)

    expect(StatusInterpreter, :apply_status, fn :homunculus, @gid, :sc_freeze, opts ->
      assert opts[:source_type] == :mob
      :ok
    end)

    assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
             HtFreezingtrap.on_unit_hit(
               group(121, :ht_freezingtrap),
               @cell,
               {:homunculus, @gid},
               @now
             )
  end

  test "mob Flasher and Shockwave use the real hostile relation for a living Homunculus" do
    stub_units([mob(1000), homunculus(@gid, 3000)])

    expect(StatusInterpreter, :apply_status, fn :homunculus, @gid, :sc_blind, opts ->
      assert opts[:source_type] == :mob
      :ok
    end)

    flasher = group(120, :ht_flasher)
    assert [{:homunculus, @gid}] = HtFlasher.unit_targets(flasher, @cell, [{:homunculus, @gid}])

    assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
             HtFlasher.on_unit_hit(flasher, @cell, {:homunculus, @gid}, @now)

    expect(Resource, :drain_sp_percent, fn {:homunculus, @gid}, 50 -> :ok end)
    shockwave = group(118, :ht_shockwave)

    assert [{:homunculus, @gid}] =
             HtShockwave.unit_targets(shockwave, @cell, [{:homunculus, @gid}])

    assert {:ok, %Group{state: %{trap: %TrapState{phase: :used}}}} =
             HtShockwave.on_unit_hit(shockwave, @cell, {:homunculus, @gid}, @now)
  end

  test "the caster's own Homunculus sets off none of its traps" do
    stub_units([player(1000), homunculus(@gid, 1000), mob(2001)])

    for {module, group} <- [
          {HtLandmine, group(116, :ht_landmine, %{base_damage: 500}, :player)},
          {HtFreezingtrap, group(121, :ht_freezingtrap, %{}, :player)},
          {HtFlasher, group(120, :ht_flasher, %{}, :player)},
          {HtShockwave, group(118, :ht_shockwave, %{}, :player)}
        ] do
      group = %{group | map_name: "prontera"}

      assert [{:mob, 2001}] =
               module.unit_targets(group, @cell, [{:homunculus, @gid}, {:mob, 2001}])
    end
  end

  defp group(skill_id, skill_name, state \\ %{}, caster_type \\ :mob) do
    %Group{
      group_id: skill_id,
      skill_id: skill_id,
      skill_name: skill_name,
      level: 3,
      caster_id: 1000,
      caster_type: caster_type,
      map_name: "trap_hom",
      center: {50, 50},
      cells: [{50, 50}],
      expires_at: 90_000,
      state: Map.put(state, :trap, armed_trap())
    }
  end
end
