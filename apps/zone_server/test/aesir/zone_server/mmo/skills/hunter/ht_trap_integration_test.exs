defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtTrapIntegrationTest.FakeMob do
  @moduledoc """
  A stand-in mob session that walks onto a trap from inside its OWN process.

  This exercises the real callback path from movement through the serialized
  skill-unit manager, including damage delivery back to the mover process.
  """
  use GenServer

  alias Aesir.ZoneServer.Unit.Movement

  def start_link(init), do: GenServer.start_link(__MODULE__, init)

  @impl true
  def init(init), do: {:ok, init}

  @impl true
  def handle_call({:walk_to, new_state}, _from, %{mob_id: id, map: map} = state) do
    Movement.set_position(:mob, id, new_state, map)
    {:reply, :ok, %{state | mob_state: new_state}}
  end

  @impl true
  def handle_cast({:apply_damage, damage, attacker_id}, %{test_pid: test_pid} = state) do
    send(test_pid, {:applied, damage, attacker_id})
    {:noreply, state}
  end
end

defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtTrapIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtTrapIntegrationTest.FakeMob
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_global
  setup :setup_ets_tables

  setup do
    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    :ok
  end

  @caster_id 1000
  @mob_id 2001
  @map "prontera"
  @trap {50, 50}

  defp build_caster do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 40, dex: 50, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1, matk: 1},
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      progression: %PlayerProgression{base_level: 50, job_level: 1, learned_skills: %{}},
      equipment: %Equipment{}
    }

    %PlayerState{
      character_id: @caster_id,
      account_id: @caster_id,
      x: 40,
      y: 40,
      map_name: @map,
      stats: stats
    }
  end

  defp build_mob_state(x, y) do
    mob_definition = %MobDefinition{
      id: 1002,
      aegis_name: "TEST_MOB",
      name: "TestMob",
      level: 1,
      hp: 1000,
      sp: 50,
      base_exp: 10,
      job_exp: 5,
      atk: 10,
      matk: 0,
      def: 5,
      mdef: 3,
      stats: %{str: 10, agi: 10, vit: 10, int: 5, dex: 10, luk: 5},
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    mob_spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: x, y: y, xs: 0, ys: 0}
    }

    %MobState{
      instance_id: @mob_id,
      mob_id: 1002,
      mob_data: mob_definition,
      spawn_ref: mob_spawn,
      x: x,
      y: y,
      map_name: @map,
      hp: 1000,
      max_hp: 1000,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    }
  end

  defp landmine_group do
    %Group{
      group_id: 999,
      skill_id: 116,
      skill_name: :ht_landmine,
      level: 3,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map,
      center: @trap,
      cells: [@trap],
      next_tick_at: System.monotonic_time(:millisecond) + 60_000,
      expires_at: System.monotonic_time(:millisecond) + 60_000,
      interval: 1_000,
      state: %{base_damage: 250}
    }
  end

  test "an enemy mob stepping onto a Land Mine takes misc damage and the trap is removed without deadlocking" do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    caster = build_caster()
    UnitRegistry.register_unit(:player, @caster_id, PlayerState, caster, self())

    {sx, sy} = {49, 50}
    mob_state = build_mob_state(sx, sy)

    {:ok, fake_mob} =
      FakeMob.start_link(%{test_pid: self(), mob_id: @mob_id, map: @map, mob_state: mob_state})

    UnitRegistry.register_unit(:mob, @mob_id, MobState, mob_state, fake_mob)
    SpatialIndex.add_unit(:mob, @mob_id, sx, sy, @map)

    :ok = Storage.insert(landmine_group())

    {tx, ty} = @trap
    walked = %{mob_state | x: tx, y: ty, movement_state: :moving}

    # The movement call waits for the Manager callback and must not deadlock.
    assert :ok = GenServer.call(fake_mob, {:walk_to, walked})

    assert_receive {:applied, damage, @caster_id}, 1_000
    assert damage > 0
    assert nil == Storage.get(999)
  end
end
