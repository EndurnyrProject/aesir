defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzSightrasherTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzSightrasher
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule FixtureUnit do
    def get_entity_info(state), do: %{stats: state}
  end

  defmodule FakeSession do
    use GenServer

    def start_link({owner, target_ref, unit_state}) do
      GenServer.start_link(__MODULE__, {owner, target_ref, unit_state})
    end

    @impl GenServer
    def init({owner, target_ref, unit_state}) do
      {:ok, %{owner: owner, target_ref: target_ref, game_state: unit_state}}
    end

    @impl GenServer
    def handle_call({:stats, :get_current_stats}, _from, state) do
      {:reply, state.game_state.stats, state}
    end

    def handle_call(:get_state, _from, state), do: {:reply, state, state}

    @impl GenServer
    def handle_cast(message, state) do
      send(state.owner, {:session_cast, state.target_ref, message})
      {:noreply, state}
    end
  end

  setup :setup_ets_tables
  setup :verify_on_exit!

  @caster %{character_id: 1_000, x: 50, y: 60}

  defp game_state do
    %{
      character_id: @caster.character_id,
      x: @caster.x,
      y: @caster.y,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{sp: 100, hp: 100},
        derived_stats: %{max_sp: 100, max_hp: 100},
        progression: %{learned_skills: %{81 => 1}},
        equipment: %Equipment{}
      }
    }
    |> Aesir.ZoneServer.PlayerStateFixture.build()
  end

  defp stub_catalog do
    stub(Catalog, :by_id, fn 81 -> {:ok, WzSightrasher.definition()} end)
    stub(Catalog, :active_module_for, fn :wz_sightrasher -> {:ok, WzSightrasher} end)
  end

  defp register_caster do
    UnitRegistry.register_unit(:player, @caster.character_id, FixtureUnit, %{}, self())
  end

  defp build_player(id, x, y) do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %CombatStats{
        atk: 1,
        def: 1,
        hit: 1,
        flee: 1,
        perfect_dodge: 1,
        matk: 100,
        matk_min: 100,
        matk_max: 100,
        heal_matk_min: 100,
        heal_matk_max: 100,
        mdef: 1,
        soft_mdef: 1,
        critical: 0,
        passive_atk: 0
      },
      derived_stats: %DerivedStats{max_hp: 100, max_sp: 100, aspd: 150},
      current_state: %CurrentState{hp: 100, sp: 100},
      progression: %PlayerProgression{base_level: 1, job_level: 1, learned_skills: %{}},
      equipment: %Equipment{}
    }

    %PlayerState{
      character_id: id,
      account_id: id,
      x: x,
      y: y,
      map_name: "prontera",
      stats: stats
    }
  end

  defp build_mob(id, x, y) do
    definition = %MobDefinition{
      id: 1002,
      aegis_name: "TEST_MOB",
      name: "Test Mob",
      level: 1,
      hp: 100,
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
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    spawn = %MobSpawn{
      mob: definition.id,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: x, y: y, xs: 0, ys: 0}
    }

    %MobState{
      instance_id: id,
      mob_id: definition.id,
      mob_data: definition,
      spawn_ref: spawn,
      x: x,
      y: y,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    }
  end

  defp register_test_unit({unit_type, unit_id} = target_ref, unit_state) do
    child_spec = %{
      id: make_ref(),
      start: {FakeSession, :start_link, [{self(), target_ref, unit_state}]}
    }

    pid = start_supervised!(child_spec)

    case unit_type do
      :player -> :ok = UnitRegistry.register_player(unit_state, pid)
      :mob -> :ok = UnitRegistry.register_unit(:mob, unit_id, MobState, unit_state, pid)
    end

    :ok =
      SpatialIndex.add_unit(unit_type, unit_id, unit_state.x, unit_state.y, unit_state.map_name)

    :ok
  end

  defp put_test_map(map) do
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", map})
  end

  test "definition matches the Renewal level 1 and level 10 data" do
    definition = WzSightrasher.definition()

    assert definition.id == 81
    assert definition.name == :wz_sightrasher
    assert definition.max_level == 10
    assert definition.target_type == :self
    assert definition.damage_type == :damage
    assert definition.damage_kind == :magic
    assert definition.element == :fire
    assert definition.range == 0
    assert definition.splash_radius == 7
    assert definition.knockback == 5
    assert definition.hit_count == 1
    assert definition.cast_time == List.duplicate(320, 10)
    assert definition.fixed_cast_time == List.duplicate(80, 10)
    assert definition.after_cast_delay == List.duplicate(2_000, 10)
    assert definition.cooldown == []
    assert definition.duration == List.duplicate(500, 10)
    assert definition.sp_cost == [35, 37, 39, 41, 43, 45, 47, 49, 51, 53]
  end

  test "a cast may begin without Sight but fizzles at cast end without resources" do
    stub_catalog()
    game_state = game_state()

    refute StatusStorage.has_status?(:player, @caster.character_id, :sc_sight)

    assert {:casting, ^game_state, %{fixed: 80, total: total}} =
             Interpreter.begin_cast(game_state, 81, 1, :self)

    assert total > 80

    reject(&Combat.execute_magic_splash/4)
    reject(&Combat.knockback/5)

    assert {:error, :sight_required} = Interpreter.complete_cast(game_state, 81, 1, :self)
    assert game_state.stats.current_state.sp == 100
    assert game_state.skill_cooldowns == %{}
    assert game_state.act_delay_until == 0
  end

  test "the cast fizzles without resources when Sight expires during cast time" do
    stub_catalog()
    :ok = register_caster()
    game_state = game_state()

    :ok =
      StatusStorage.apply_status(:player, @caster.character_id, :sc_sight,
        caster_id: @caster.character_id,
        duration: 10_000
      )

    assert {:casting, ^game_state, %{fixed: 80, total: total}} =
             Interpreter.begin_cast(game_state, 81, 1, :self)

    assert total > 80

    :ok = StatusStorage.remove_status(:player, @caster.character_id, :sc_sight)

    reject(&Combat.execute_magic_splash/4)
    reject(&Combat.knockback/5)

    assert {:error, :sight_required} = Interpreter.complete_cast(game_state, 81, 1, :self)
    assert game_state.stats.current_state.sp == 100
    assert game_state.skill_cooldowns == %{}
    assert game_state.act_delay_until == 0
  end

  test "a level 1 cast consumes Sight before dealing Fire damage and knockback" do
    :ok = register_caster()

    :ok =
      StatusStorage.apply_status(:player, @caster.character_id, :sc_sight,
        caster_id: @caster.character_id,
        duration: 10_000
      )

    expect(Combat, :execute_magic_splash, fn @caster, {50, 60}, 7, opts ->
      refute StatusStorage.has_status?(:player, @caster.character_id, :sc_sight)
      assert opts[:skill_id] == 81
      assert opts[:skill_level] == 1
      assert opts[:skill_ratio] == 120
      assert opts[:element] == :fire
      assert opts[:split] == false
      assert opts[:base_distance] == 5
      assert opts[:origin] == {50, 60}
      [{:mob, 2_001}, {:player, 2_002}]
    end)

    reject(&Combat.knockback/5)

    assert {:ok, @caster} =
             WzSightrasher.cast(@caster, :self, 1, WzSightrasher.definition())

    refute StatusStorage.has_status?(:player, @caster.character_id, :sc_sight)
  end

  test "a successful level 10 cast consumes SP and arms the after-cast delay" do
    stub_catalog()
    :ok = register_caster()

    game_state = put_in(game_state().stats.progression.learned_skills[81], 10)

    :ok =
      StatusStorage.apply_status(:player, @caster.character_id, :sc_sight,
        caster_id: @caster.character_id,
        duration: 10_000
      )

    expect(Combat, :execute_magic_splash, fn @caster, {50, 60}, 7, opts ->
      refute StatusStorage.has_status?(:player, @caster.character_id, :sc_sight)
      assert opts[:skill_level] == 10
      assert opts[:skill_ratio] == 300
      assert opts[:element] == :fire
      []
    end)

    reject(&Combat.knockback/5)

    assert {:ok, updated} = Interpreter.cast(game_state, 81, 10, :self)
    assert updated.stats.current_state.sp == 47
    assert updated.act_delay_until > System.monotonic_time(:millisecond)
    refute StatusStorage.has_status?(:player, @caster.character_id, :sc_sight)
  end

  test "real splash damages and knocks back only hostile mobs in the radius-7 square, excluding players" do
    collision_id = 2_000
    outside_id = 2_001
    party_ally_id = 3_001
    guild_ally_id = 3_002

    caster = %{build_player(@caster.character_id, 50, 60) | party_id: 10, guild_id: 20}
    hostile_player = build_player(collision_id, 50, 59)
    hostile_mob = build_mob(collision_id, 57, 60)
    outside_mob = build_mob(outside_id, 58, 60)
    party_ally = %{build_player(party_ally_id, 51, 60) | party_id: 10}
    guild_ally = %{build_player(guild_ally_id, 52, 60) | guild_id: 20}

    map = MapData.new("prontera", 100, 100) |> MapData.set_cell(50, 55, GatType.wall())
    true = put_test_map(map)

    :ok = register_test_unit({:player, caster.character_id}, caster)
    :ok = register_test_unit({:player, collision_id}, hostile_player)
    :ok = register_test_unit({:mob, collision_id}, hostile_mob)
    :ok = register_test_unit({:mob, outside_id}, outside_mob)
    :ok = register_test_unit({:player, party_ally_id}, party_ally)
    :ok = register_test_unit({:player, guild_ally_id}, guild_ally)

    :ok =
      StatusStorage.apply_status(:player, caster.character_id, :sc_sight,
        caster_id: caster.character_id,
        duration: 10_000
      )

    assert {:ok, ^caster} =
             WzSightrasher.cast(caster, :self, 1, WzSightrasher.definition())

    refute StatusStorage.has_status?(:player, caster.character_id, :sc_sight)

    assert_receive {:session_cast, {:mob, ^collision_id},
                    {:combat, {:apply_damage, mob_damage, 1_000}}}

    assert mob_damage > 0

    assert_receive {:session_cast, {:mob, ^collision_id},
                    {:movement, {:displace, _expected_x, _expected_y, "prontera", 62, 60}}}

    excluded = [
      {:player, caster.character_id},
      {:player, collision_id},
      {:mob, outside_id},
      {:player, party_ally_id},
      {:player, guild_ally_id}
    ]

    Enum.each(excluded, fn target_ref ->
      refute_received {:session_cast, ^target_ref,
                       {:combat, {:apply_damage, _damage, _attacker_id}}}

      refute_received {:session_cast, ^target_ref,
                       {:movement, {:displace, _expected_x, _expected_y, _map, _x, _y}}}
    end)
  end
end
