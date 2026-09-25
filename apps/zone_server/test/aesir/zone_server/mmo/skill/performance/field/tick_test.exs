defmodule Aesir.ZoneServer.Mmo.Skill.Performance.Field.TickTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field.Tick
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Resource
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(Resource)
    Mimic.copy(DamageApplication)
    :ok
  end

  test "Dissonance sends neutral misc damage with the frozen lesson level" do
    test_pid = self()

    stub(Combat, :execute_misc_attack, fn _caster, target, opts ->
      send(test_pid, {target, opts})
      :ok
    end)

    group = group(3, :dissonance, 10)
    assert :ok = Tick.dissonance(group, %{}, [{:mob, 42}])
    assert_received {{:mob, 42}, opts}
    assert opts[:skill_id] == 317
    assert opts[:skill_level] == 3
    assert opts[:base_damage] == 90
    assert opts[:element] == :neutral
  end

  test "Ugly Dance drains fixed SP from every eligible target" do
    test_pid = self()

    stub(Resource, :drain_sp, fn type, id, amount ->
      send(test_pid, {type, id, amount})
      :ok
    end)

    assert :ok = Tick.ugly_dance(group(3, :ugly_dance, 10), %{}, [{:mob, 42}])
    assert_received {:mob, 42, 50}
  end

  test "Idun heals a player by the frozen VIT formula but excludes its caster" do
    test_pid = self()

    stub(DamageApplication, :apply_heal, fn type, id, amount, source ->
      send(test_pid, {type, id, amount, source})
      :ok
    end)

    group = group(5, :idun_heal, 0)
    group = put_in(group.state.performance.caster_vit, 12)
    assert :ok = Tick.idun_heal(group, %{}, [{:player, 1}, {:player, 42}])
    assert_received {:player, 42, 61, 1}
    refute_received {:player, 1, _, _}
  end

  test "an absent caster does not tick or advance deadlines" do
    stub(Combat, :resolve_combatant, fn :player, 1 -> {:error, :target_not_found} end)
    group = group(3, :dissonance, 0)
    assert {:ok, ^group} = Tick.run(group, 5_000)
  end

  test "a dissonant cell damages an enemy even when the song has no ordinary tick" do
    caster =
      PlayerState.new(%Character{
        id: 1,
        account_id: 1,
        name: "Bard",
        last_map: "prontera",
        last_x: 2,
        last_y: 2,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 50,
        job_level: 50,
        class: 19
      })

    mob = %MobState{
      instance_id: 42,
      mob_id: 1002,
      mob_data: nil,
      spawn_ref: nil,
      x: 2,
      y: 2,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    :ok = UnitRegistry.register_player(caster, self())
    :ok = UnitRegistry.register_unit(:mob, 42, MobState, mob, self())
    :ok = SpatialIndex.add_unit(:player, 1, 2, 2, "prontera")
    :ok = SpatialIndex.add_unit(:mob, 42, 2, 2, "prontera")

    stub(Combat, :resolve_combatant, fn :player, 1 ->
      {:ok, %{unit_type: :player, unit_id: 1, map_name: "prontera"}}
    end)

    test_pid = self()

    stub(Combat, :execute_misc_attack, fn _caster, target, opts ->
      send(test_pid, {:hit, target, opts[:skill_id]})
      :ok
    end)

    group = group(3, nil, 10)
    group = %{group | cells: [{2, 2}]}
    group = put_in(group.state.performance.dissonant_cells, MapSet.new([{2, 2}]))
    assert {:ok, updated} = Tick.run(group, 1_000)
    assert_received {:hit, {:mob, 42}, 317}
    refute_received {:hit, {:player, 1}, _}
    assert updated.state.performance.next_overlap_at == 4_000
    assert {:ok, ^updated} = Tick.run(updated, 2_000)
    refute_received {:hit, _, _}
  end

  test "a 1 s manager call before the effect interval does not run the effect" do
    stub(Combat, :resolve_combatant, fn :player, 1 -> {:ok, %{}} end)

    group =
      group(3, :dissonance, 0)
      |> put_in([Access.key(:state), :performance, :next_effect_at], 4_000)

    assert {:ok, ^group} = Tick.run(group, 3_000)
  end

  defp group(level, tick, lesson) do
    %Group{
      group_id: 7,
      skill_name: :performance,
      skill_id: 317,
      level: level,
      caster_type: :player,
      caster_id: 1,
      map_name: "prontera",
      cells: [],
      state: %{
        performance: %{
          kind: :song,
          tick: tick,
          tick_interval: 3_000,
          next_effect_at: 0,
          dissonant_cells: MapSet.new(),
          lesson_level: lesson,
          caster_vit: 0
        }
      }
    }
  end
end
