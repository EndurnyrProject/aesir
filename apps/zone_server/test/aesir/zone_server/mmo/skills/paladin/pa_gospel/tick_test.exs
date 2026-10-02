defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.TickTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Effects
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Tick
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 49_001
  @ally_id 49_002
  @stranger_id 49_003
  @mob_id 49_004
  @party 77
  @cell {40, 40}

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(Effects)

    caster = player(@caster_id, @party)
    :ok = UnitRegistry.register_player(caster, self())
    :ok = SpatialIndex.add_unit(:player, @caster_id, 40, 40, "prontera")

    stub(Combat, :resolve_combatant, fn :player, @caster_id ->
      {:ok, %{unit_type: :player, unit_id: @caster_id, map_name: "prontera", party_id: @party}}
    end)

    %{caster: caster}
  end

  test "blesses a party member, afflicts an enemy, and skips the caster and strangers" do
    place_player(@ally_id, @party)
    place_player(@stranger_id, 0)
    place_mob(@mob_id)
    test_pid = self()

    stub(Effects, :bless, fn _group, target ->
      send(test_pid, {:bless, target})
      :ok
    end)

    stub(Effects, :afflict, fn _group, _caster_state, target ->
      send(test_pid, {:afflict, target})
      :ok
    end)

    group = group(5, fn _ -> 1 end)

    assert {:ok, ^group} = Tick.run(group, 10_000)

    assert_received {:bless, {:player, @ally_id}}
    assert_received {:afflict, {:mob, @mob_id}}
    refute_received {:bless, {:player, @caster_id}}
    refute_received {:afflict, {:player, @caster_id}}
    refute_received {:bless, {:player, @stranger_id}}
    refute_received {:afflict, {:player, @stranger_id}}
  end

  test "the per-unit roll passes at 50 + 5 * level and fails above it" do
    place_player(@ally_id, @party)
    test_pid = self()

    stub(Effects, :bless, fn _group, target ->
      send(test_pid, {:bless, target})
      :ok
    end)

    assert {:ok, _} = Tick.run(group(4, fn 100 -> 70 end), 10_000)
    assert_received {:bless, {:player, @ally_id}}

    assert {:ok, _} = Tick.run(group(4, fn 100 -> 71 end), 10_000)
    refute_received {:bless, _}
  end

  test "a vanished caster expires the field" do
    stub(Combat, :resolve_combatant, fn :player, @caster_id -> {:error, :target_not_found} end)
    group = group(1, fn _ -> 1 end)

    assert {:expire, ^group} = Tick.run(group, 10_000)
  end

  defp group(level, rng) do
    %Group{
      group_id: 11,
      skill_id: 369,
      skill_name: :pa_gospel,
      level: level,
      caster_id: @caster_id,
      caster_type: :player,
      party_id: @party,
      map_name: "prontera",
      center: @cell,
      cells: [@cell],
      state: %{rng: rng}
    }
  end

  defp place_player(id, party_id) do
    :ok = UnitRegistry.register_player(player(id, party_id), self())
    :ok = SpatialIndex.add_unit(:player, id, 40, 40, "prontera")
  end

  defp place_mob(id) do
    mob = %MobState{
      instance_id: id,
      mob_id: 1002,
      mob_data: nil,
      spawn_ref: nil,
      x: 40,
      y: 40,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    :ok = UnitRegistry.register_unit(:mob, id, MobState, mob, self())
    :ok = SpatialIndex.add_unit(:mob, id, 40, 40, "prontera")
  end

  defp player(id, party_id) do
    state =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Unit #{id}",
        last_map: "prontera",
        last_x: 40,
        last_y: 40,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 90,
        job_level: 50,
        class: 4015
      })

    %{state | party_id: party_id}
  end
end
