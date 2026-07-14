defmodule Aesir.ZoneServer.Mmo.Skills.WzJupitelTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skills.WzJupitel
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  @target_id 2000

  defmodule FakeSession do
    use GenServer

    def start_link({owner, unit_state}) do
      GenServer.start_link(__MODULE__, {owner, unit_state})
    end

    @impl GenServer
    def init({owner, unit_state}), do: {:ok, %{owner: owner, game_state: unit_state}}

    @impl GenServer
    def handle_call(:get_current_stats, _from, state) do
      {:reply, state.game_state.stats, state}
    end

    def handle_call(:get_state, _from, state), do: {:reply, state, state}

    @impl GenServer
    def handle_cast(message, state) do
      send(state.owner, {:session_cast, message})
      {:noreply, state}
    end
  end

  defp caster(opts \\ []) do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{
        atk: 1,
        def: 1,
        hit: 1,
        flee: 1,
        perfect_dodge: 1,
        matk: 100,
        matk_min: 100,
        matk_max: 100,
        mdef: 1,
        soft_mdef: 1
      },
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      progression: %PlayerProgression{base_level: 1, job_level: 1, learned_skills: %{}},
      equipment: %Equipment{}
    }

    struct!(
      PlayerState,
      Keyword.merge(
        [
          character_id: 1000,
          account_id: 1000,
          x: 50,
          y: 60,
          map_name: "prontera",
          stats: stats
        ],
        opts
      )
    )
  end

  defp mob_state(opts) do
    x = Keyword.get(opts, :x, 65)
    y = Keyword.get(opts, :y, 60)

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
      attack_delay: 1000,
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

    struct!(
      MobState,
      Keyword.merge(
        [
          instance_id: @target_id,
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
        ],
        opts
      )
    )
  end

  defp put_test_map(map_data \\ MapData.new("prontera", 100, 100)) do
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", map_data})
  end

  defp register_mob(opts \\ []) do
    state = mob_state(opts)
    {:ok, pid} = start_supervised({FakeSession, {self(), state}})
    :ok = UnitRegistry.register_unit(:mob, @target_id, MobState, state, pid)
    :ok = SpatialIndex.add_unit(:mob, @target_id, state.x, state.y, state.map_name)
    {state, pid}
  end

  defp register_player(opts \\ []) do
    state = caster(Keyword.merge([character_id: @target_id, account_id: @target_id, x: 65], opts))
    {:ok, pid} = start_supervised({FakeSession, {self(), state}})
    :ok = UnitRegistry.register_player(state, pid)
    :ok = SpatialIndex.add_unit(:player, @target_id, state.x, state.y, state.map_name)
    {state, pid}
  end

  test "definition matches the Renewal level 1 and level 10 data" do
    definition = WzJupitel.definition()

    assert definition.id == 84
    assert definition.name == :wz_jupitel
    assert definition.max_level == 10
    assert definition.target_type == :target_enemy
    assert definition.damage_type == :damage
    assert definition.damage_kind == :magic
    assert definition.element == :wind
    assert definition.range == 9
    assert definition.cast_time == [2000, 2200, 2400, 2600, 2800, 3000, 3200, 3400, 3600, 3800]
    assert definition.fixed_cast_time == List.duplicate(500, 10)
    assert definition.after_cast_delay == []
    assert definition.cooldown == []
    assert definition.sp_cost == [20, 23, 26, 29, 32, 35, 38, 41, 44, 47]
  end

  test "a cast schedules one typed impact at 150ms without dealing early damage" do
    caster = caster()
    definition = WzJupitel.definition()
    started_at = System.monotonic_time(:millisecond)

    expect(Combat, :resolve_combatant, fn @target_id ->
      {:ok, %{unit_type: :mob}}
    end)

    reject(&Combat.execute_magic_attack/3)
    reject(&Combat.knockback/5)

    assert {:ok, ^caster} = WzJupitel.cast(caster, {:unit, @target_id}, 1, definition)

    refute_receive {:jupitel_impact, _impact}, 140

    assert_receive {:jupitel_impact,
                    %{
                      target: {:mob, @target_id},
                      skill_level: 1
                    }},
                   100

    assert System.monotonic_time(:millisecond) - started_at >= 150
    refute_receive {:jupitel_impact, _impact}, 50
  end

  test "a clear delayed impact carries the level 1 magic and knockback parameters" do
    caster = caster()
    impact = %{target: {:mob, @target_id}, skill_level: 1}

    true = put_test_map()
    :ok = SpatialIndex.add_unit(:mob, @target_id, 55, 60, "prontera")

    expect(Combat, :execute_magic_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == 84
      assert opts[:skill_level] == 1
      assert opts[:skill_ratio] == 100
      assert opts[:hit_count] == 3
      assert opts[:element] == :wind
      assert opts[:skip_range] == true
      :ok
    end)

    expect(Combat, :knockback, fn :mob, @target_id, 50, 60, 2 ->
      {:ok, {57, 60}}
    end)

    assert :ok = WzJupitel.impact(caster, impact)
  end

  test "the player session resolves an impact against a registered mob beyond attack range" do
    caster = caster()
    impact = %{target: {:mob, @target_id}, skill_level: 1}
    map = MapData.new("prontera", 100, 100) |> MapData.set_cell(67, 60, GatType.wall())

    true = put_test_map(map)
    {_mob, _pid} = register_mob()

    assert {:noreply, %{game_state: ^caster}} =
             PlayerSession.handle_info({:jupitel_impact, impact}, %{game_state: caster})

    assert_receive {:session_cast, {:apply_damage, damage, 1000}}
    assert damage > 0
    assert_receive {:session_cast, {:knocked_back, 66, 60}}
    refute_receive {:session_cast, {:apply_damage, _damage, _attacker_id}}, 20
    refute_receive {:session_cast, {:knocked_back, _x, _y}}, 20
  end

  test "impact rechecks mob life and does not damage or knock back a dead target" do
    true = put_test_map()
    {_mob, _pid} = register_mob(hp: 0, is_dead: true)

    assert {:error, :target_dead} =
             WzJupitel.impact(caster(), %{target: {:mob, @target_id}, skill_level: 1})

    refute_receive {:session_cast, {:apply_damage, _damage, _attacker_id}}, 20
    refute_receive {:session_cast, {:knocked_back, _x, _y}}, 20
  end

  test "impact rechecks line of sight and stops at an intervening wall" do
    map = MapData.new("prontera", 100, 100) |> MapData.set_cell(58, 60, GatType.wall())
    true = put_test_map(map)
    {_mob, _pid} = register_mob()

    assert {:error, :blocked_line_of_sight} =
             WzJupitel.impact(caster(), %{target: {:mob, @target_id}, skill_level: 1})

    refute_receive {:session_cast, {:apply_damage, _damage, _attacker_id}}, 20
    refute_receive {:session_cast, {:knocked_back, _x, _y}}, 20
  end

  test "impact line of sight treats an intervening Ice Wall as unreachable" do
    map = MapData.new("prontera", 100, 100) |> MapData.set_cell_flag(58, 60, :icewall, true)
    true = put_test_map(map)
    {_mob, _pid} = register_mob()

    assert {:error, :blocked_line_of_sight} =
             WzJupitel.impact(caster(), %{target: {:mob, @target_id}, skill_level: 1})

    refute_receive {:session_cast, {:apply_damage, _damage, _attacker_id}}, 20
    refute_receive {:session_cast, {:knocked_back, _x, _y}}, 20
  end

  test "diagonal line of sight checks the static cells visited by rAthena traversal" do
    map = MapData.new("prontera", 100, 100) |> MapData.set_cell(51, 60, GatType.wall())
    true = put_test_map(map)
    {_mob, _pid} = register_mob(x: 54, y: 62)

    assert {:error, :blocked_line_of_sight} =
             WzJupitel.impact(caster(), %{target: {:mob, @target_id}, skill_level: 1})

    refute_receive {:session_cast, {:apply_damage, _damage, _attacker_id}}, 20
    refute_receive {:session_cast, {:knocked_back, _x, _y}}, 20
  end

  test "diagonal line of sight ignores Ice Wall cells outside rAthena traversal" do
    map = MapData.new("prontera", 100, 100) |> MapData.set_cell_flag(51, 61, :icewall, true)
    true = put_test_map(map)
    {_mob, _pid} = register_mob(x: 54, y: 62)

    assert :ok =
             WzJupitel.impact(caster(), %{target: {:mob, @target_id}, skill_level: 1})

    assert_receive {:session_cast, {:apply_damage, damage, 1000}}
    assert damage > 0
    assert_receive {:session_cast, {:knocked_back, 56, 64}}
  end

  test "impact accepts a living enemy player after the central relation check" do
    true = put_test_map()
    {_player, _pid} = register_player()

    assert :ok =
             WzJupitel.impact(caster(), %{target: {:player, @target_id}, skill_level: 1})

    assert_receive {:session_cast, {:apply_damage, damage, 1000}}
    assert damage > 0
    assert_receive {:session_cast, {:knocked_back, 67, 60}}
  end

  test "impact rejects a same-party player through the central relation check" do
    true = put_test_map()
    {_player, _pid} = register_player(party_id: 10)

    assert {:error, :invalid_target} =
             WzJupitel.impact(caster(party_id: 10), %{
               target: {:player, @target_id},
               skill_level: 1
             })

    refute_receive {:session_cast, {:apply_damage, _damage, _attacker_id}}, 20
    refute_receive {:session_cast, {:knocked_back, _x, _y}}, 20
  end

  test "rejects an invalid target before damage or knockback" do
    caster = caster()

    expect(Combat, :resolve_combatant, fn @target_id ->
      {:error, :target_not_found}
    end)

    reject(&Combat.execute_magic_attack/3)
    reject(&Combat.knockback/5)

    assert {:error, :target_not_found} =
             WzJupitel.cast(caster, {:unit, @target_id}, 1, WzJupitel.definition())
  end
end
