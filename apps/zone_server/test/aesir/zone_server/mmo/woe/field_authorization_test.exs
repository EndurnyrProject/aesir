defmodule Aesir.ZoneServer.Mmo.Woe.FieldAuthorizationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    :ok = MapFlags.reload()
    :ok
  end

  test "a player-owned field authorizes only living same-party targets on a versus map" do
    caster = player(1_201, {150, 150}, party_id: 7)
    ally = player(1_202, {151, 150}, party_id: 7)
    attacker = combatant(caster)
    target = combatant(ally)
    ally_state = get_player_state(ally.pid)
    dead_target = %{put_in(ally_state.stats.current_state.hp, 0) | action_state: :dead}
    group = group(:wz_quagmire, 92, caster.character.id)

    assert {:error, :invalid_target} = Targeting.validate_field_target(group, attacker, target)
    assert {:error, :target_dead} = Targeting.validate_field_target(group, attacker, dead_target)

    :ok = MapFlags.set_runtime("prontera", :pvp, true)

    assert :ok = Targeting.validate_field_target(group, attacker, target)
    assert {:error, :target_dead} = Targeting.validate_field_target(group, attacker, dead_target)
    assert {:error, :invalid_target} = Targeting.validate_enemy(attacker, target)
  end

  test "field selection includes a friendly but ordinary selection remains enemy-only" do
    caster = player(1_211, {150, 150}, guild_id: 8)
    ally = player(1_212, {151, 150}, guild_id: 8)
    _outside = player(1_213, {152, 150}, guild_id: 8)
    attacker = combatant(caster)
    group = group(:am_demonstration, 229, caster.character.id)

    :ok = MapFlags.set_runtime("prontera", :pvp, true)

    assert SplashTargets.select_field(group, {150, 150}, 1, attacker) == [
             {:player, ally.character.id}
           ]

    assert SplashTargets.select("prontera", {150, 150}, 1, attacker) == []
  end

  test "a field-owned physical hit damages a friendly while the ordinary entry rejects it" do
    caster = player(1_221, {150, 150}, party_id: 9)
    ally = player(1_222, {151, 150}, party_id: 9)
    caster_state = get_player_state(caster.pid)
    target_ref = {:player, ally.character.id}
    group = group(:am_demonstration, 229, caster.character.id)
    initial_hp = player_hp(ally)
    opts = [skill_id: 229, skill_level: 1, fixed_damage: 100, ignore_flee: true, report_hit: true]

    :ok = MapFlags.set_runtime("prontera", :pvp, true)

    assert {:error, :invalid_target} =
             SkillAttack.execute_skill_attack(caster_state, target_ref, opts)

    assert {:ok, %{hit?: true, damage: 100, target_survives?: true, coma?: false}} =
             SkillAttack.execute_field_skill_attack(caster_state, target_ref, group, opts)

    assert_eventually(fn -> player_hp(ally) == initial_hp - 100 end)
  end

  test "a field physical splash returns typed connected friendlies for follow-up effects" do
    caster = player(1_231, {150, 150}, guild_id: 10)
    ally = player(1_232, {151, 150}, guild_id: 10)
    caster_state = get_player_state(caster.pid)
    group = group(:ht_freezingtrap, 121, caster.character.id)
    initial_hp = player_hp(ally)

    :ok = MapFlags.set_runtime("prontera", :pvp, true)

    assert SkillAttack.execute_field_splash_attack(caster_state, {150, 150}, 1, group,
             skill_id: 121,
             skill_level: 1,
             skill_ratio: 100,
             element: :water,
             ignore_flee: true,
             skip_crit: true
           ) == [{:player, ally.character.id}]

    assert_eventually(fn -> player_hp(ally) < initial_hp end)
  end

  test "a field-owned misc hit damages a friendly while the ordinary entry rejects it" do
    caster = player(1_241, {150, 150}, party_id: 11)
    ally = player(1_242, {151, 150}, party_id: 11)
    caster_state = get_player_state(caster.pid)
    target_ref = {:player, ally.character.id}
    group = group(:ht_landmine, 116, caster.character.id)
    initial_hp = player_hp(ally)
    opts = [skill_id: 116, skill_level: 1, base_damage: 100, ignore_element: true]

    :ok = MapFlags.set_runtime("prontera", :pvp, true)

    assert {:error, :invalid_target} =
             SkillAttack.execute_misc_attack(caster_state, target_ref, opts)

    assert :ok = SkillAttack.execute_field_misc_attack(caster_state, target_ref, group, opts)
    assert_eventually(fn -> player_hp(ally) < initial_hp end)
  end

  test "a field misc splash splits its base over the authorized friendly set" do
    caster = player(1_251, {150, 150}, guild_id: 12)
    ally_a = player(1_252, {151, 150}, guild_id: 12)
    ally_b = player(1_253, {150, 151}, guild_id: 12)
    caster_state = get_player_state(caster.pid)
    group = group(:ht_blastmine, 122, caster.character.id)
    initial_a = player_hp(ally_a)
    initial_b = player_hp(ally_b)

    :ok = MapFlags.set_runtime("prontera", :pvp, true)

    assert :ok =
             SkillAttack.execute_field_misc_splash(caster_state, {150, 150}, 1, group,
               skill_id: 122,
               skill_level: 1,
               base_damage: 200,
               element: :wind,
               ignore_element: true,
               split: true
             )

    assert_eventually(fn ->
      player_hp(ally_a) == initial_a - 100 and player_hp(ally_b) == initial_b - 100
    end)
  end

  test "castle ground alone preserves PvE field hostility and mob-owned fields stay ordinary" do
    caster = player(1_261, {150, 150}, party_id: 13)
    ally = player(1_262, {151, 150}, party_id: 13)
    mob = start_mob_session(unit_id: 1_263, position: {150, 151}, hp: 1_000, max_hp: 1_000)
    attacker = combatant(caster)
    friendly = combatant(ally)
    mob_target = mob.mob_state.__struct__.to_combatant(mob.mob_state)
    field = group(:wz_quagmire, 92, caster.character.id)

    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)

    assert {:error, :invalid_target} = Targeting.validate_field_target(field, attacker, friendly)
    assert :ok = Targeting.validate_field_target(field, attacker, mob_target)

    :ok = MapFlags.set_runtime("prontera", :gvg, true)
    assert :ok = Targeting.validate_field_target(field, attacker, friendly)

    mob_field = group(:ht_landmine, 116, mob.unit_id, %{caster_type: :mob})

    assert {:error, :invalid_field_source} =
             Targeting.validate_field_target(mob_field, mob_target, friendly)

    assert :ok = Targeting.validate_enemy(mob_target, friendly)
  end

  test "field source and option identity cannot be spoofed" do
    caster = player(1_271, {150, 150})
    target = player(1_272, {151, 150})
    caster_state = get_player_state(caster.pid)
    attacker = combatant(caster)
    target_combatant = combatant(target)
    valid = group(:am_demonstration, 229, caster.character.id)

    :ok = MapFlags.set_runtime("prontera", :pvp, true)

    for invalid <- [
          %{valid | caster_id: caster.character.id + 1},
          %{valid | caster_type: :mob},
          %{valid | map_name: "geffen"},
          %{valid | skill_name: :ht_landmine},
          %{valid | skill_id: 999},
          %{valid | skill_id: nil, skill_name: nil}
        ] do
      assert {:error, :invalid_field_source} =
               Targeting.validate_field_target(invalid, attacker, target_combatant)
    end

    assert {:error, :field_skill_mismatch} =
             SkillAttack.execute_field_skill_attack(
               caster_state,
               {:player, target.character.id},
               valid,
               skill_id: 92,
               skill_level: 1,
               fixed_damage: 100,
               ignore_flee: true
             )

    assert {:error, :field_skill_mismatch} =
             SkillAttack.execute_field_misc_attack(
               caster_state,
               {:player, target.character.id},
               valid,
               skill_id: 229,
               skill_level: 2,
               base_damage: 100
             )
  end

  test "field selection retains concrete-skill objective eligibility" do
    :ok = CastleDb.reload()
    :ok = CastleStore.init()
    castle = CastleDb.all() |> hd()
    start_per_test_map(castle.map)
    {x, y} = castle.emperium
    caster = player(1_281, {x, y}, guild_id: 17, map_name: castle.map)

    objective =
      start_mob_session(
        unit_id: 1_282,
        mob_id: 1288,
        map_name: castle.map,
        position: {x + 1, y},
        hp: 1_000,
        max_hp: 1_000
      )

    :ok = MapFlags.set_runtime(castle.map, :gvg, true)
    :ok = CastleStore.set_siege(castle.id, true)
    :ok = CastleStore.set_emperium(castle.id, objective.unit_id)

    stub(GuildManager, :get, fn 17 ->
      {:ok,
       %GuildState{
         guild_id: 17,
         name: "Field Guild",
         master_char_id: caster.character.id,
         learned_skills: %{10_000 => 1}
       }}
    end)

    attacker = combatant(caster)
    target = objective.mob_state.__struct__.to_combatant(objective.mob_state)

    field =
      group(:am_demonstration, 229, caster.character.id, %{
        map_name: castle.map,
        center: {x, y},
        cells: [{x, y}]
      })

    assert {:error, :skill_not_allowed} = Targeting.validate_field_target(field, attacker, target)
    assert SplashTargets.select_field(field, {x, y}, 1, attacker) == []
  end

  defp player(id, position, opts \\ []) do
    map_name = Keyword.get(opts, :map_name, "prontera")

    player =
      start_player_session(
        id: id,
        account_id: id,
        name: "Field#{id}",
        map_name: map_name,
        position: position,
        base_level: 99,
        hp: 5_000,
        max_hp: 5_000
      )

    :sys.replace_state(player.pid, fn session ->
      game_state = %{
        session.game_state
        | party_id: Keyword.get(opts, :party_id, 0),
          guild_id: Keyword.get(opts, :guild_id, 0)
      }

      %{session | game_state: game_state}
    end)

    :ok = UnitRegistry.update_unit_state(:player, id, get_player_state(player.pid))
    player
  end

  defp combatant(player) do
    state = get_player_state(player.pid)
    state.__struct__.to_combatant(state)
  end

  defp player_hp(player), do: get_player_state(player.pid).stats.current_state.hp

  defp group(skill_name, skill_id, caster_id, attrs \\ %{}) do
    struct!(
      Group,
      Map.merge(
        %{
          group_id: System.unique_integer([:positive]),
          skill_name: skill_name,
          skill_id: skill_id,
          level: 1,
          caster_type: :player,
          caster_id: caster_id,
          map_name: "prontera",
          center: {150, 150},
          cells: [{150, 150}],
          state: %{}
        },
        attrs
      )
    )
  end
end
