defmodule Aesir.ZoneServer.Mmo.Woe.DamagePathsTest do
  @moduledoc """
  Tests damage delivery and objective guards with real status application.
  Positive fixture rolls are pinned while zero-chance paths, including absent reflection, stay false.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.GameMode
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcSelfdestruction
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    stub(Resistance, :roll_success, fn chance -> chance > 0 end)
    :ok = MapFlags.reload()
    :ok = CastleDb.reload()
    :ok = CastleStore.init()
    :ok
  end

  test "staged delivery settles a valid hit and rejects a current inactive objective" do
    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)
    attacker = player(101, "prontera", {150, 150})
    target = mob(201, 1002, "prontera", {151, 150}, 1_000)
    attacker_state = get_player_state(attacker.pid)

    stub(DamageCalculator, :calculate_damage, fn _attacker, _target, _opts ->
      {:ok, %{damage: 100, is_critical: false}}
    end)

    assert {:ok, valid_hit} =
             SkillAttack.prepare_staged_skill_attack(attacker_state, {:mob, target.unit_id},
               skill_id: 7,
               skill_level: 1,
               ignore_flee: true
             )

    assert :ok = SkillAttack.deliver_prepared_skill_hit(valid_hit)
    assert_receive {:packet_sent, %SkillDamage{target_id: 201, damage: 60}, _}
    assert_eventually(fn -> get_mob_state(target.pid).hp == 940 end)

    assert {:ok, delayed_hit} =
             SkillAttack.prepare_staged_skill_attack(attacker_state, {:mob, target.unit_id},
               skill_id: 7,
               skill_level: 1,
               ignore_flee: true
             )

    :ok = StatusInterpreter.apply_status(:mob, target.unit_id, :sc_aeterna)
    objective = mob_state(201, 1288, "prontera", {151, 150})
    :ok = UnitRegistry.update_unit_state(:mob, target.unit_id, objective)

    assert :ok = SkillAttack.deliver_prepared_skill_hit(delayed_hit)
    refute_receive {:packet_sent, %SkillDamage{target_id: 201}, _}, 100
    assert get_mob_state(target.pid).hp == 940
    assert StatusStorage.has_status?(:mob, target.unit_id, :sc_aeterna)
  end

  test "eligible pre-renewal Triple Attack rechecks ended and replaced objectives" do
    castle = CastleDb.all() |> hd()
    start_per_test_map(castle.map)
    :ok = MapFlags.set_runtime(castle.map, :gvg, true)
    :ok = CastleStore.set_siege(castle.id, true)
    :ok = CastleStore.set_emperium(castle.id, 202)

    {x, y} = castle.emperium
    attacker = player(102, castle.map, {x, y}, %{}, 7)
    objective = mob(202, 1288, castle.map, {x + 1, y})
    attacker_state = get_player_state(attacker.pid)

    stub(GuildManager, :get, fn 7 -> {:ok, approval_guild(7)} end)

    stub(DamageCalculator, :calculate_damage, fn _attacker, _target, _opts ->
      {:ok, %{damage: 100, is_critical: false}}
    end)

    prepare = fn ->
      SkillAttack.prepare_staged_skill_attack(attacker_state, {:mob, objective.unit_id},
        skill_id: 263,
        skill_level: 1,
        fixed_damage: 100,
        ignore_flee: true
      )
    end

    case GameMode.mode() do
      :renewal ->
        assert {:error, :skill_not_allowed} = prepare.()

      :pre_renewal ->
        initial_hp = get_mob_state(objective.pid).hp
        assert {:ok, ended_hit} = prepare.()

        :ok =
          StatusInterpreter.apply_status(:mob, objective.unit_id, :sc_aeterna,
            loaded: true,
            duration: 60_000
          )

        :ok = MapFlags.set_runtime(castle.map, :gvg, false)
        :ok = CastleStore.set_siege(castle.id, false)

        assert :ok = SkillAttack.deliver_prepared_skill_hit(ended_hit)
        assert get_mob_state(objective.pid).hp == initial_hp
        assert StatusStorage.has_status?(:mob, objective.unit_id, :sc_aeterna)

        :ok = MapFlags.set_runtime(castle.map, :gvg, true)
        :ok = CastleStore.set_siege(castle.id, true)
        :ok = CastleStore.set_emperium(castle.id, objective.unit_id)
        assert {:ok, replaced_hit} = prepare.()
        :ok = CastleStore.set_emperium(castle.id, objective.unit_id + 1)

        assert :ok = SkillAttack.deliver_prepared_skill_hit(replaced_hit)
        refute_receive {:packet_sent, %SkillDamage{target_id: 202}, _}, 100
        assert get_mob_state(objective.pid).hp == initial_hp
        assert StatusStorage.has_status?(:mob, objective.unit_id, :sc_aeterna)
    end
  end

  test "public fixed, misc, explicit magic, and ground magic entries agree on packet and HP damage" do
    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)
    attacker = player(103, "prontera", {150, 150})
    attacker_state = get_player_state(attacker.pid)
    attacker_combatant = attacker_state.__struct__.to_combatant(attacker_state)

    stub(DamageCalculator, :calculate_damage, fn _attacker, _target, _opts ->
      {:ok, %{damage: 100, is_critical: false}}
    end)

    stub(MiscDamageCalculator, :calculate_misc_damage, fn _attacker, _target, _opts ->
      {:ok, %{damage: 100, is_critical: false}}
    end)

    stub(MagicDamageCalculator, :calculate_magic_damage, fn _attacker, _target, _opts ->
      {:ok, %{damage: 100, is_critical: false}}
    end)

    entries = [
      {:physical_fixed, :ok,
       fn target_id ->
         SkillAttack.execute_skill_attack(attacker_state, {:mob, target_id},
           skill_id: 7,
           skill_level: 1,
           fixed_damage: 100,
           ignore_flee: true
         )
       end},
      {:misc, :ok,
       fn target_id ->
         SkillAttack.execute_misc_attack(attacker_state, {:mob, target_id},
           skill_id: 122,
           skill_level: 1,
           base_damage: 100,
           element: :neutral
         )
       end},
      {:explicit_magic, {:ok, {:mob, 304}},
       fn target_id ->
         MagicAttack.execute_magic_damage(attacker_state, {:mob, target_id}, 100,
           skill_id: 28,
           skill_level: 1,
           element: :neutral,
           skip_range: true
         )
       end},
      {:ground_magic, :ok,
       fn target_id ->
         MagicAttack.apply_skill_unit_damage(
           attacker_combatant,
           :mob,
           target_id,
           89,
           1,
           :neutral,
           100
         )
       end},
      {:fixed_ground_magic, :ok,
       fn target_id ->
         MagicAttack.apply_skill_unit_damage(
           attacker_combatant,
           :mob,
           target_id,
           89,
           1,
           :neutral,
           0,
           fixed_damage: 100
         )
       end}
    ]

    entries
    |> Enum.with_index(302)
    |> Enum.each(fn {{name, expected, entry}, target_id} ->
      target = mob(target_id, 1002, "prontera", {151, 150}, 1_000)
      :ok = StatusInterpreter.apply_status(:mob, target_id, :sc_aeterna)

      expected = if name == :explicit_magic, do: {:ok, {:mob, target_id}}, else: expected
      assert entry.(target_id) == expected

      assert_receive {:packet_sent, %SkillDamage{target_id: ^target_id, damage: 120}, _},
                     200,
                     inspect(name)

      assert_eventually(fn -> get_mob_state(target.pid).hp == 880 end)
      refute StatusStorage.has_status?(:mob, target_id, :sc_aeterna), inspect(name)
    end)
  end

  test "reflected explicit magic settles at the caster with one skill rate" do
    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)
    :ok = MapFlags.set_runtime("prontera", :pvp, true)
    caster = player(104, "prontera", {150, 150})
    reflector = player(105, "prontera", {151, 150}, %{magic_damage_return: 100})
    caster_id = caster.character.id
    caster_hp = player_hp(caster)
    reflector_hp = player_hp(reflector)
    :ok = StatusInterpreter.apply_status(:player, caster_id, :sc_aeterna)

    assert {:ok, {:player, ^caster_id}} =
             MagicAttack.execute_magic_damage(
               get_player_state(caster.pid),
               {:player, reflector.character.id},
               100,
               skill_id: 19,
               skill_level: 1,
               element: :neutral,
               skip_range: true
             )

    assert_receive {:packet_sent, %SkillDamage{target_id: ^caster_id, skill_id: 19, damage: 120},
                    _}

    assert_eventually(fn -> player_hp(caster) == caster_hp - 120 end)
    assert player_hp(reflector) == reflector_hp
    refute StatusStorage.has_status?(:player, caster_id, :sc_aeterna)
  end

  test "Self Destruction rates enemy damage, gates an inactive objective, and keeps its self-cost raw" do
    castle = CastleDb.all() |> hd()
    start_per_test_map(castle.map)
    :ok = MapFlags.set_runtime(castle.map, :gvg_castle, true)
    :ok = MapFlags.set_runtime(castle.map, :gvg, false)

    {x, y} = castle.emperium
    caster = mob(501, 1002, castle.map, {x, y}, 100)
    target = mob(502, 1002, castle.map, {x + 1, y}, 1_000)
    objective = mob(503, 1288, castle.map, {x, y + 1})
    caster_state = get_mob_state(caster.pid)

    stub(Combat, :splash_targets, fn map, origin, 5, %{unit_type: :mob, unit_id: 501} ->
      assert map == castle.map
      assert origin == {x, y}
      [{:mob, target.unit_id}, {:mob, objective.unit_id}]
    end)

    :ok = StatusInterpreter.apply_status(:mob, target.unit_id, :sc_aeterna)

    :ok =
      StatusInterpreter.apply_status(:mob, objective.unit_id, :sc_aeterna,
        loaded: true,
        duration: 60_000
      )

    objective_hp = get_mob_state(objective.pid).hp
    objective_position = SpatialIndex.get_unit_position(:mob, objective.unit_id)

    assert {:ok, ^caster_state} =
             NpcSelfdestruction.cast(
               caster_state,
               {:unit, caster.unit_id},
               1,
               NpcSelfdestruction.definition()
             )

    assert_eventually(fn ->
      state = get_mob_state(target.pid)
      state.hp == 880 and Map.has_key?(state.typed_aggro_list, {:mob, caster.unit_id})
    end)

    assert_eventually(fn -> get_mob_state(caster.pid).hp == 0 end)
    assert get_mob_state(objective.pid).hp == objective_hp
    assert SpatialIndex.get_unit_position(:mob, objective.unit_id) == objective_position
    refute StatusStorage.has_status?(:mob, target.unit_id, :sc_aeterna)
    assert StatusStorage.has_status?(:mob, objective.unit_id, :sc_aeterna)
  end

  test "raw status damage does not acquire the castle skill rate" do
    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)
    target = mob(601, 1002, "prontera", {151, 150}, 1_000)

    assert :ok = MagicAttack.deal_damage({:mob, target.unit_id}, 100)
    assert_eventually(fn -> get_mob_state(target.pid).hp == 900 end)
    refute_receive {:packet_sent, %SkillDamage{target_id: 601}, _}, 100
  end

  defp player(id, map_name, position, equipment \\ %{}, guild_id \\ 0) do
    player =
      start_player_session(
        id: id,
        account_id: id,
        name: "Task7#{id}",
        map_name: map_name,
        position: position,
        base_level: 99,
        hp: 5_000,
        max_hp: 5_000
      )

    :sys.replace_state(player.pid, fn session ->
      stats = session.game_state.stats

      stats = %{
        stats
        | current_state: %{stats.current_state | hp: stats.derived_stats.max_hp},
          modifiers: %{stats.modifiers | equipment: equipment}
      }

      game_state = %{session.game_state | stats: stats, guild_id: guild_id}
      %{session | game_state: game_state}
    end)

    :ok = UnitRegistry.update_unit_state(:player, id, get_player_state(player.pid))
    player
  end

  defp mob(unit_id, mob_id, map_name, position, hp \\ nil) do
    state = mob_state(unit_id, mob_id, map_name, position, hp)
    {:ok, pid} = MobSession.start_link(%{state: state, awake: false})
    :ok = UnitRegistry.register_unit(:mob, unit_id, MobState, state, pid)
    {x, y} = position
    :ok = SpatialIndex.add_unit(:mob, unit_id, x, y, map_name)
    %{pid: pid, unit_id: unit_id}
  end

  defp mob_state(unit_id, mob_id, map_name, {x, y}, hp \\ nil) do
    {:ok, mob_data} = Mobs.by_id(mob_id)

    spawn = %MobSpawn{
      mob: mob_id,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: x, y: y}
    }

    state = MobState.new(unit_id, mob_data, spawn, map_name, x, y)

    case hp do
      nil -> state
      hp -> %{state | hp: hp, max_hp: hp, base_max_hp: hp}
    end
  end

  defp approval_guild(guild_id) do
    %GuildState{
      guild_id: guild_id,
      name: "Task 7 Guild",
      master_char_id: guild_id,
      learned_skills: %{10_000 => 1}
    }
  end

  defp player_hp(player), do: get_player_state(player.pid).stats.current_state.hp
end
