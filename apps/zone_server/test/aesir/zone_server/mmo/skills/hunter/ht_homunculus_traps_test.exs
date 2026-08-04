defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtHomunculusTrapsTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
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
    Mimic.copy(Trap)
    Mimic.copy(Resource)
    :ok
  end

  @gid 1_500_001
  @caster %MobState{
    instance_id: 1000,
    mob_id: 1002,
    mob_data: %{element: {:neutral, 1}, race: :formless, modes: []},
    spawn_ref: nil,
    map_name: "trap_hom",
    x: 50,
    y: 50,
    hp: 100,
    max_hp: 100,
    sp: 10,
    max_sp: 10,
    spawned_at: 0
  }

  test "mob Land Mine uses the real hostile relation for Homunculus damage and Stun" do
    stub(Trap, :resolve_caster, fn _group -> {:ok, @caster} end)
    stub(Trap, :roll_damage, fn 500 -> 500 end)

    expect(Combat, :execute_misc_attack, fn @caster, {:homunculus, @gid}, opts ->
      assert opts[:skill_id] == 116
      :ok
    end)

    expect(StatusInterpreter, :apply_status, fn :homunculus, @gid, :sc_stun, opts ->
      assert opts[:source_type] == :mob
      :ok
    end)

    assert :expire =
             HtLandmine.on_touch(
               group(116, :ht_landmine, %{base_damage: 500}),
               {:homunculus, @gid}
             )
  end

  test "mob Freezing Trap retains the exact typed connected Homunculus" do
    stub(Trap, :resolve_caster, fn _group -> {:ok, @caster} end)

    stub(SpatialIndex, :get_unit_position, fn :homunculus, @gid -> {:ok, {51, 50, "trap_hom"}} end)

    expect(Combat, :execute_splash_attack, fn @caster, {51, 50}, 1, opts ->
      assert opts[:typed_results]
      [{:homunculus, @gid}]
    end)

    expect(StatusInterpreter, :apply_status, fn :homunculus, @gid, :sc_freeze, opts ->
      assert opts[:source_type] == :mob
      :ok
    end)

    assert :expire = HtFreezingtrap.on_touch(group(121, :ht_freezingtrap), {:homunculus, @gid})
  end

  test "mob Flasher and Shockwave use the real hostile relation for a living Homunculus" do
    expect(StatusInterpreter, :apply_status, fn :homunculus, @gid, :sc_blind, opts ->
      assert opts[:source_type] == :mob
      :ok
    end)

    assert :expire = HtFlasher.on_touch(group(120, :ht_flasher), {:homunculus, @gid})

    expect(Resource, :drain_sp_percent, fn {:homunculus, @gid}, 50 -> :ok end)
    assert :expire = HtShockwave.on_touch(group(118, :ht_shockwave), {:homunculus, @gid})
  end

  test "player-side Homunculus contact leaves every trap armed" do
    reject(&Combat.execute_misc_attack/3)
    reject(&Combat.execute_splash_attack/4)
    reject(&StatusInterpreter.apply_status/4)
    reject(&Resource.drain_sp_percent/2)

    for {module, group} <- [
          {HtLandmine, group(116, :ht_landmine, %{base_damage: 500}, :player)},
          {HtFreezingtrap, group(121, :ht_freezingtrap, %{}, :player)},
          {HtFlasher, group(120, :ht_flasher, %{}, :player)},
          {HtShockwave, group(118, :ht_shockwave, %{}, :player)}
        ] do
      assert {:ok, %Group{}} = module.on_touch(group, {:homunculus, @gid})
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
      state: state
    }
  end
end
