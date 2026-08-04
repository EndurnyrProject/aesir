defmodule Aesir.ZoneServer.HomunculusInteractionMatrixTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.Relationship
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlBlessing
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlCure
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlIncagi
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrProvidence
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrSlowpoison
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrStrecovery
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaDispell
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfDetoxify
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "hom_interaction_matrix"

  setup do
    owner = start_owner("Owner")
    foreign = start_owner("Foreign")

    on_exit(fn ->
      stop_if_alive(owner.pid)
      stop_if_alive(foreign.pid)
    end)

    %{owner: owner, foreign: foreign}
  end

  test "PvE hostility follows social roots without turning foreign player-side roots hostile", %{
    owner: owner,
    foreign: foreign
  } do
    owner_state = PlayerSession.get_state(owner.pid)
    foreign_state = PlayerSession.get_state(foreign.pid)
    owner_combatant = owner_state.game_state.__struct__.to_combatant(owner_state.game_state)
    hom_combatant = owner_state.homunculus.__struct__.to_combatant(owner_state.homunculus)
    foreign_hom = foreign_state.homunculus.__struct__.to_combatant(foreign_state.homunculus)
    mob = mob_combatant()

    refute Relationship.enemy?(owner_combatant, hom_combatant)
    refute Relationship.enemy?(hom_combatant, owner_combatant)
    refute Relationship.enemy?(owner_combatant, foreign_hom)
    refute Relationship.enemy?(hom_combatant, foreign_hom)
    assert Relationship.enemy?(owner_combatant, mob)
    assert Relationship.enemy?(hom_combatant, mob)
    assert Relationship.enemy?(mob, owner_combatant)
    assert Relationship.enemy?(mob, hom_combatant)
    refute Targeting.versus_map?(@map)
  end

  test "owner Heal, Blessing, Dispell, and Providence support the exact owned Homunculus", %{
    owner: owner
  } do
    state = PlayerSession.get_state(owner.pid)
    gid = state.homunculus.world_gid
    target = {:unit, {:homunculus, gid}}

    :sys.replace_state(owner.pid, fn current ->
      %{current | homunculus: %{current.homunculus | hp: current.homunculus.hp - 200}}
    end)

    grant_skill(owner.pid, AlHeal.definition().id, 1)
    before_heal = PlayerSession.get_state(owner.pid)

    simulate_incoming_message(owner.pid, %SkillCast{
      skill_id: AlHeal.definition().id,
      level: 1,
      target_id: gid
    })

    assert_eventually(fn ->
      healed = PlayerSession.get_state(owner.pid)

      Process.alive?(owner.pid) and healed.homunculus.hp > before_heal.homunculus.hp and
        healed.game_state.stats.current_state.sp ==
          before_heal.game_state.stats.current_state.sp - 13
    end)

    refute_received {:packet_sent, %SkillCastFailed{skill_id: 28}, _}

    caster = PlayerSession.get_state(owner.pid).game_state
    assert :ok = AlBlessing.validate(caster, target, 1, AlBlessing.definition())
    assert {:ok, ^caster} = AlBlessing.cast(caster, target, 1, AlBlessing.definition())
    assert StatusStorage.has_status?(:homunculus, gid, :sc_blessing)

    assert :ok = CrProvidence.validate(caster, target, 1, CrProvidence.definition())
    assert {:ok, ^caster} = CrProvidence.cast(caster, target, 1, CrProvidence.definition())
    assert StatusStorage.has_status?(:homunculus, gid, :sc_providence)

    assert :ok = StatusInterpreter.apply_status(:homunculus, gid, :sc_increaseagi)
    assert :ok = SaDispell.validate(caster, target, 5, SaDispell.definition())

    assert {:ok, ^caster} =
             SaDispell.cast(caster, target, 5, SaDispell.definition(), rng: fn 100 -> 1 end)

    refute StatusStorage.has_status?(:homunculus, gid, :sc_increaseagi)
  end

  test "foreign direct support rejects before changing Homunculus state", %{
    owner: owner,
    foreign: foreign
  } do
    target_state = PlayerSession.get_state(owner.pid)
    caster = PlayerSession.get_state(foreign.pid).game_state
    gid = target_state.homunculus.world_gid
    target = {:unit, {:homunculus, gid}}
    before = target_state.homunculus

    grant_skill(foreign.pid, AlHeal.definition().id, 1)
    foreign_before = PlayerSession.get_state(foreign.pid).game_state

    simulate_incoming_message(foreign.pid, %SkillCast{
      skill_id: AlHeal.definition().id,
      level: 1,
      target_id: gid
    })

    assert_receive {:packet_sent, %SkillCastFailed{skill_id: 28}, _}, 1_000
    foreign_after = PlayerSession.get_state(foreign.pid).game_state
    assert foreign_after.stats.current_state.sp == foreign_before.stats.current_state.sp
    assert foreign_after.skill_cooldowns == foreign_before.skill_cooldowns
    assert foreign_after.act_delay_until == foreign_before.act_delay_until

    for {module, level} <- [{AlBlessing, 1}, {SaDispell, 5}, {CrProvidence, 1}] do
      assert {:error, :invalid_target} =
               module.validate(caster, target, level, module.definition())
    end

    assert PlayerSession.get_state(owner.pid).homunculus == before
    assert StatusStorage.get_unit_statuses(:homunculus, gid) == []
  end

  test "owner Cure removes Homunculus status through PlayerSession", %{owner: owner} do
    gid = PlayerSession.get_state(owner.pid).homunculus.world_gid

    assert :ok =
             StatusInterpreter.apply_status(:homunculus, gid, :sc_silence,
               bypass_resistance: true
             )

    cast_owner_support(owner.pid, AlCure, 1, gid, :sc_silence, false)
  end

  test "owner Detoxify removes Homunculus status through PlayerSession", %{owner: owner} do
    gid = PlayerSession.get_state(owner.pid).homunculus.world_gid

    assert :ok =
             StatusInterpreter.apply_status(:homunculus, gid, :sc_poison, bypass_resistance: true)

    cast_owner_support(owner.pid, TfDetoxify, 1, gid, :sc_poison, false)
  end

  test "owner Increase AGI applies Homunculus status through PlayerSession", %{owner: owner} do
    gid = PlayerSession.get_state(owner.pid).homunculus.world_gid

    cast_owner_support(owner.pid, AlIncagi, 1, gid, :sc_increaseagi, true)
  end

  test "owner Status Recovery removes Homunculus status through PlayerSession", %{owner: owner} do
    gid = PlayerSession.get_state(owner.pid).homunculus.world_gid

    assert :ok =
             StatusInterpreter.apply_status(:homunculus, gid, :sc_stun, bypass_resistance: true)

    cast_owner_support(owner.pid, PrStrecovery, 1, gid, :sc_stun, false)
  end

  test "owner Slow Poison applies Homunculus status through PlayerSession", %{owner: owner} do
    gid = PlayerSession.get_state(owner.pid).homunculus.world_gid

    cast_owner_support(owner.pid, PrSlowpoison, 1, gid, :sc_slowpoison, true)
  end

  test "foreign support skills reject Homunculus targets before resource settlement", %{
    owner: owner,
    foreign: foreign
  } do
    for pid <- [owner.pid, foreign.pid] do
      :sys.replace_state(pid, fn state ->
        %{state | game_state: %{state.game_state | party_id: 1, guild_id: 1}}
      end)
    end

    gid = PlayerSession.get_state(owner.pid).homunculus.world_gid

    assert :ok =
             StatusInterpreter.apply_status(:homunculus, gid, :sc_poison, bypass_resistance: true)

    before_homunculus = PlayerSession.get_state(owner.pid).homunculus
    before_statuses = StatusStorage.get_unit_statuses(:homunculus, gid)

    for {module, level} <- [
          {AlCure, 1},
          {TfDetoxify, 1},
          {AlIncagi, 1},
          {PrStrecovery, 1},
          {PrSlowpoison, 1}
        ] do
      grant_skill(foreign.pid, module.definition().id, level)
      before_caster = PlayerSession.get_state(foreign.pid).game_state

      simulate_incoming_message(foreign.pid, %SkillCast{
        skill_id: module.definition().id,
        level: level,
        target_id: gid
      })

      assert_receive {:packet_sent, %SkillCastFailed{skill_id: skill_id}, _}, 1_000
      assert skill_id == module.definition().id

      after_caster = PlayerSession.get_state(foreign.pid).game_state
      assert after_caster.stats.current_state.sp == before_caster.stats.current_state.sp
      assert after_caster.skill_cooldowns == before_caster.skill_cooldowns
      assert after_caster.act_delay_until == before_caster.act_delay_until
      assert PlayerSession.get_state(owner.pid).homunculus == before_homunculus
      assert StatusStorage.get_unit_statuses(:homunculus, gid) == before_statuses
    end
  end

  test "extended level 48 Decrease AGI executes through the real mob pipeline", %{owner: owner} do
    gid = PlayerSession.get_state(owner.pid).homunculus.world_gid
    mob = %{mob_state() | target_ref: {:homunculus, gid}}
    row = %{skill: :al_decagi, skill_id: 30, level: 48, target: :target}

    assert :ok = Executor.execute(mob, row)

    assert %{val1: 48, source_id: 9_001, source_type: :mob, expires_at: expires_at} =
             StatusStorage.get_status(:homunculus, gid, :sc_decreaseagi)

    remaining = expires_at - System.monotonic_time(:millisecond)
    assert remaining in 1..130_000
  end

  test "generic statuses apply while the exact player/equipment/resource set stays excluded", %{
    owner: owner
  } do
    gid = PlayerSession.get_state(owner.pid).homunculus.world_gid

    assert :ok =
             StatusInterpreter.apply_status(:homunculus, gid, :sc_poison, bypass_resistance: true)

    assert StatusStorage.has_status?(:homunculus, gid, :sc_poison)

    excluded = [
      :sc_adrenaline,
      :sc_adrenaline2,
      :sc_spearquicken,
      :sc_twohandquicken,
      :sc_devoted_by,
      :sc_devotion,
      :sc_energycoat,
      :sc_magiccandy,
      :sc_magicrod,
      :sc_maximizepower,
      :sc_sightblaster
    ]

    for status <- excluded do
      assert {:error, :ineligible_target} =
               StatusInterpreter.apply_status(:homunculus, gid, status)
    end
  end

  test "typed healing remains on the Homunculus under a same-number mob collision", %{
    owner: owner
  } do
    state = PlayerSession.get_state(owner.pid)
    gid = state.homunculus.world_gid

    mob = %MobState{
      instance_id: gid,
      mob_id: 1002,
      mob_data: %{element: {:water, 1}, race: :plant, size: :medium, modes: []},
      spawn_ref: nil,
      hp: 500,
      max_hp: 500,
      sp: 10,
      max_sp: 10,
      map_name: @map,
      x: 50,
      y: 50,
      spawned_at: 0
    }

    :ok = UnitRegistry.register_unit(:mob, gid, MobState, mob, self())
    on_exit(fn -> UnitRegistry.unregister_unit(:mob, gid) end)

    reduced_hp = state.homunculus.hp - 100

    :sys.replace_state(owner.pid, fn current ->
      %{current | homunculus: %{current.homunculus | hp: reduced_hp}}
    end)

    grant_skill(owner.pid, AlHeal.definition().id, 1)

    simulate_incoming_message(owner.pid, %SkillCast{
      skill_id: AlHeal.definition().id,
      level: 1,
      target_id: gid
    })

    assert_eventually(fn -> PlayerSession.get_state(owner.pid).homunculus.hp > reduced_hp end)

    assert {:ok, {MobState, %{hp: 500}, _pid}} = UnitRegistry.get_unit(:mob, gid)
  end

  defp cast_owner_support(pid, module, level, gid, status_id, expected?) do
    grant_skill(pid, module.definition().id, level)
    before_caster = PlayerSession.get_state(pid).game_state

    expected_sp =
      before_caster.stats.current_state.sp - Enum.at(module.definition().sp_cost, level - 1)

    simulate_incoming_message(pid, %SkillCast{
      skill_id: module.definition().id,
      level: level,
      target_id: gid
    })

    assert_eventually(fn ->
      state = PlayerSession.get_state(pid)

      StatusStorage.has_status?(:homunculus, gid, status_id) == expected? and
        state.game_state.stats.current_state.sp == expected_sp
    end)

    refute_received {:packet_sent, %SkillCastFailed{}, _}
  end

  defp start_owner(prefix) do
    suffix = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "matrix_#{prefix}_#{suffix}",
        user_pass: "password",
        email: "matrix-#{prefix}-#{suffix}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "#{prefix}#{suffix}",
        class: 5,
        base_level: 50,
        job_level: 50,
        hp: 1_000,
        max_hp: 1_000,
        sp: 500,
        max_sp: 500,
        last_map: @map,
        last_x: 50,
        last_y: 50
      })
      |> Repo.insert()

    insert_homunculus(character.id)
    character = Repo.preload(character, :homunculus)
    start_player_session(character: character)
  end

  defp insert_homunculus(character_id) do
    %Homunculus{}
    |> Homunculus.changeset(%{
      character_id: character_id,
      class_id: 6_001,
      name: "Hildr",
      lifecycle: "active",
      level: 50,
      hp: 800,
      max_hp: 1_000,
      sp: 150,
      max_sp: 200,
      str: 11,
      agi: 12,
      vit: 13,
      int: 14,
      dex: 15,
      luk: 16,
      active_remaining_ms: 1_800_000,
      learned_skills: %{"8001" => 1},
      cooldowns: %{},
      ai_config: %{}
    })
    |> Repo.insert!()
  end

  defp grant_skill(pid, skill_id, level) do
    :sys.replace_state(pid, fn state ->
      progression = state.game_state.stats.progression

      progression = %{
        progression
        | learned_skills: Map.put(progression.learned_skills, skill_id, level)
      }

      stats = %{state.game_state.stats | progression: progression}
      %{state | game_state: %{state.game_state | stats: stats}}
    end)
  end

  defp stop_if_alive(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
  end

  defp mob_combatant, do: mob_state() |> MobState.to_combatant()

  defp mob_state do
    %MobState{
      instance_id: 9_001,
      mob_id: 1002,
      spawn_ref: nil,
      hp: 100,
      max_hp: 100,
      sp: 10,
      max_sp: 10,
      spawned_at: 0,
      map_name: @map,
      x: 51,
      y: 50,
      mob_data: %MobDefinition{
        id: 1002,
        aegis_name: "PORING",
        name: "Poring",
        level: 1,
        hp: 100,
        stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        race: :plant,
        element: {:water, 1},
        size: :medium,
        modes: [],
        atk: 10,
        matk: 10,
        def: 0,
        mdef: 0,
        attack_range: 1,
        skill_range: 10,
        walk_speed: 200,
        attack_delay: 1_000,
        attack_motion: 500,
        client_attack_motion: 500,
        damage_motion: 500
      }
    }
  end
end
