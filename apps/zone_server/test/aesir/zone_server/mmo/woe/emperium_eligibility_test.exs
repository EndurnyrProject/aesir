defmodule Aesir.ZoneServer.Mmo.Woe.EmperiumEligibilityTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.AutoAttack
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @emperium_mob_id 1288
  @emperium_unit_id 20_001

  defmodule TestUnit do
    defstruct [:combatant, :stats, :hp]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
    def get_stats(%__MODULE__{stats: stats, hp: hp}), do: Map.put(stats || %{}, :hp, hp)
  end

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(HitCalculations)
    Mimic.copy(SkillAttack)
    :ok = CastleDb.reload()
    :ok = MapFlags.reload()
    :ok = CastleStore.init()

    castle = CastleDb.all() |> hd()
    :ok = MapFlags.set_runtime(castle.map, :gvg, true)
    :ok = CastleStore.set_siege(castle.id, true)
    :ok = CastleStore.set_emperium(castle.id, @emperium_unit_id)

    %{castle: castle}
  end

  test "target policy retains raw mob identity and rejects an unrecorded Emperium", %{
    castle: castle
  } do
    attacker = %{
      character_id: 10_001,
      guild_id: 7,
      party_id: 0,
      map_name: castle.map,
      action_state: :idle,
      stats: %{current_state: %{hp: 100}}
    }

    target = %{
      instance_id: @emperium_unit_id + 1,
      mob_id: @emperium_mob_id,
      map_name: castle.map,
      hp: 100,
      is_dead: false
    }

    assert Targeting.validate_enemy(attacker, target) == {:error, :stale_emperium}
  end

  test "a guild without Approval cannot attack the live Emperium", %{castle: castle} do
    attacker = player_combatant(7, castle)
    target = emperium_combatant(castle)

    stub(GuildManager, :get, fn 7 -> {:ok, guild_state(7, %{})} end)

    assert Rules.validate_target(attacker, target, %{skill_id: nil}) ==
             {:error, :approval_required}
  end

  test "Triple Attack replacement follows the boot-selected mode without ordinary fallback", %{
    castle: castle
  } do
    attacker = player_combatant(7, castle)
    target = emperium_combatant(castle)
    caster_state = %TestUnit{combatant: attacker, stats: %{}, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}
    replacement_opts = [skill_id: 263, skill_level: 1, ignore_flee: true]

    stub(GuildManager, :get, fn 7 -> {:ok, guild_state(7, %{10_000 => 1})} end)

    stub(TargetResolver, :resolve, fn @emperium_unit_id ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, [projectile?: true] -> :ok end)

    stub(StatusInterpreter, :on_committed_action, fn :player, 10_001, :normal_attack ->
      :unchanged
    end)

    stub(StatusInterpreter, :before_weapon_hit, fn :mob, @emperium_unit_id, _info -> :continue end)

    stub(Passives, :attack_replacement, fn ^caster_state ->
      {:skill_attack, replacement_opts, :triple_attack}
    end)

    case GameMode.mode() do
      :renewal ->
        reject(&SkillAttack.execute_skill_attack/3)

        assert {{:error, :skill_not_allowed}, ^caster_state} =
                 AutoAttack.execute_attack(
                   %{},
                   caster_state,
                   @emperium_unit_id,
                   &Function.identity/1
                 )

      :pre_renewal ->
        stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

        expect(SkillAttack, :execute_skill_attack, fn ^caster_state,
                                                      @emperium_unit_id,
                                                      ^replacement_opts ->
          :ok
        end)

        assert {{:ok, {:combo, :triple_attack, {:mob, @emperium_unit_id}, _delay}}, ^caster_state} =
                 AutoAttack.execute_attack(
                   %{},
                   caster_state,
                   @emperium_unit_id,
                   &Function.identity/1
                 )
    end
  end

  test "ordinary attacks require an active exact non-owner Approval guild", %{castle: castle} do
    attacker = player_combatant(7, castle)
    target = emperium_combatant(castle)

    stub(GuildManager, :get, fn 7 -> {:ok, guild_state(7, %{10_000 => 1})} end)

    assert :ok = Rules.validate_target(attacker, target, %{skill_id: nil})

    :ok = CastleStore.hydrate(%{castle.id => 7})
    assert {:error, :owner_guild} = Rules.validate_target(attacker, target, %{skill_id: nil})

    :ok = MapFlags.set_runtime(castle.map, :gvg, false)
    assert {:error, :siege_inactive} = Rules.validate_target(attacker, target, %{skill_id: nil})
  end

  test "non-objective targets remain neutral without guild or siege state", %{castle: castle} do
    target = %{emperium_combatant(castle) | monster_id: 1002}
    assert :ok = Rules.validate_target(player_combatant(0, castle), target, %{skill_id: 19})
  end

  test "eligible bow normals deliver ranged metadata", %{castle: castle} do
    attacker =
      7
      |> player_combatant(castle)
      |> Map.merge(%{attack_range: 5, weapon: %{type: :bow, element: :wind, size: :all}})

    target = emperium_combatant(castle)
    caster_state = %TestUnit{combatant: attacker, stats: %{}, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}

    stub(GuildManager, :get, fn 7 -> {:ok, guild_state(7, %{10_000 => 1})} end)
    stub(TargetResolver, :resolve, fn @emperium_unit_id -> {:ok, self(), target_state, :mob} end)
    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, [projectile?: true] -> :ok end)

    stub(StatusInterpreter, :on_committed_action, fn :player, 10_001, :normal_attack ->
      :unchanged
    end)

    stub(StatusInterpreter, :before_weapon_hit, fn :mob, @emperium_unit_id, _info -> :continue end)

    stub(StatusInterpreter, :absorb_damage, fn :mob, @emperium_unit_id, 40, hit_info ->
      refute hit_info.is_short
      40
    end)

    stub(StatusInterpreter, :after_damage_taken, fn :mob, @emperium_unit_id, _hit_info -> 0 end)
    stub(Passives, :attack_replacement, fn ^caster_state -> :normal end)
    stub(Passives, :attack_procs, fn ^caster_state -> %{} end)
    stub(Passives, :after_normal_hit, fn ^caster_state, _hit -> :ok end)
    stub(Passives, :steal_proc, fn ^caster_state -> 0 end)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    stub(DamageCalculator, :calculate_damage, fn ^attacker, ^target, _opts ->
      {:ok, %{damage: 40, is_critical: false}}
    end)

    stub(EquipBreak, :resolve, fn _stats, _target -> [] end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(MobSession, :apply_damage, fn _pid, 40, {:player, 10_001} -> :ok end)

    assert {:ok, ^caster_state} =
             AutoAttack.execute_attack(%{}, caster_state, @emperium_unit_id, &Function.identity/1)
  end

  test "eligible Homunculus normal uses its owner's guild snapshot", %{castle: castle} do
    owner_id = 10_001
    homunculus_id = 30_001
    target = emperium_combatant(castle)
    target_state = %TestUnit{combatant: target, stats: %{}, hp: 100}
    homunculus = homunculus_state(castle, owner_id, homunculus_id)

    attacker = HomunculusState.to_combatant(homunculus)

    :ok = UnitRegistry.register_unit(:player, owner_id, TestUnit, %{guild_id: 7}, self())
    stub(GuildManager, :get, fn 7 -> {:ok, guild_state(7, %{10_000 => 1})} end)

    stub(TargetResolver, :resolve, fn {:mob, @emperium_unit_id} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, [projectile?: true] -> :ok end)

    stub(StatusInterpreter, :before_normal_attack, fn :homunculus, ^homunculus_id, _info ->
      %{}
    end)

    stub(StatusInterpreter, :absorb_damage, fn :mob, @emperium_unit_id, damage, _hit_info ->
      damage
    end)

    stub(StatusInterpreter, :after_damage_taken, fn :mob, @emperium_unit_id, _hit_info -> 0 end)
    stub(StatusInterpreter, :on_dealt_damage, fn :homunculus, ^homunculus_id, _info -> [] end)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    stub(DamageCalculator, :calculate_damage, fn ^attacker, ^target, _opts ->
      {:ok, %{damage: 40, is_critical: false}}
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    stub(MobSession, :apply_damage, fn _pid, damage, {:homunculus, ^homunculus_id}
                                       when damage > 0 ->
      :ok
    end)

    assert :ok = AutoAttack.execute_homunculus_attack(homunculus, {:mob, @emperium_unit_id})
  end

  test "Homunculus normal denies a missing owner, missing Approval, and the owner guild", %{
    castle: castle
  } do
    owner_id = 10_001
    homunculus_id = 30_001
    homunculus = homunculus_state(castle, owner_id, homunculus_id)
    attacker = HomunculusState.to_combatant(homunculus)
    target = emperium_combatant(castle)
    target_state = %TestUnit{combatant: target, stats: %{}, hp: 100}

    stub(TargetResolver, :resolve, fn {:mob, @emperium_unit_id} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, [projectile?: true] -> :ok end)
    reject(&StatusInterpreter.before_normal_attack/3)

    assert {:error, :guild_required} =
             AutoAttack.execute_homunculus_attack(homunculus, {:mob, @emperium_unit_id})

    :ok = UnitRegistry.register_unit(:player, owner_id, TestUnit, %{guild_id: 7}, self())
    stub(GuildManager, :get, fn 7 -> {:ok, Process.get(:task4_hom_guild)} end)
    Process.put(:task4_hom_guild, guild_state(7, %{}))

    assert {:error, :approval_required} =
             AutoAttack.execute_homunculus_attack(homunculus, {:mob, @emperium_unit_id})

    Process.put(:task4_hom_guild, guild_state(7, %{10_000 => 1}))
    :ok = CastleStore.hydrate(%{castle.id => 7})

    assert {:error, :owner_guild} =
             AutoAttack.execute_homunculus_attack(homunculus, {:mob, @emperium_unit_id})
  end

  test "physical skill metadata carries the status attack endow", %{castle: castle} do
    attacker = player_combatant(7, castle)
    target = %{emperium_combatant(castle, @emperium_unit_id + 2) | monster_id: 1002}
    target_id = target.unit_id
    caster_state = %TestUnit{combatant: attacker, stats: %{}, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}

    stub(TargetResolver, :resolve, fn {:mob, ^target_id} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :mob, ^target_id, _info -> :continue end)

    stub(ModifierCalculator, :get_all_modifiers, fn :player, 10_001 ->
      %{attack_element: :fire}
    end)

    stub(StatusInterpreter, :absorb_damage, fn :mob, ^target_id, 40, hit_info ->
      assert hit_info.element == :fire
      40
    end)

    stub(StatusInterpreter, :after_damage_taken, fn :mob, ^target_id, _hit_info -> 0 end)

    stub(DamageCalculator, :calculate_damage, fn ^attacker, ^target, opts ->
      refute Keyword.has_key?(opts, :element)
      {:ok, %{damage: 40, is_critical: false}}
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(MobSession, :apply_damage, fn _pid, 40, 10_001 -> :ok end)

    assert :ok =
             SkillAttack.execute_skill_attack(caster_state, {:mob, target_id},
               skill_id: 7,
               skill_level: 1,
               ignore_flee: true
             )
  end

  test "physical skill element override wins over the status attack endow", %{castle: castle} do
    attacker = player_combatant(7, castle)
    target = %{emperium_combatant(castle, @emperium_unit_id + 2) | monster_id: 1002}
    target_id = target.unit_id
    caster_state = %TestUnit{combatant: attacker, stats: %{}, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}

    stub(TargetResolver, :resolve, fn {:mob, ^target_id} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :mob, ^target_id, _info -> :continue end)

    stub(ModifierCalculator, :get_all_modifiers, fn :player, 10_001 ->
      %{attack_element: :fire}
    end)

    stub(StatusInterpreter, :absorb_damage, fn :mob, ^target_id, 40, hit_info ->
      assert hit_info.element == :poison
      40
    end)

    stub(StatusInterpreter, :after_damage_taken, fn :mob, ^target_id, _hit_info -> 0 end)

    stub(DamageCalculator, :calculate_damage, fn ^attacker, ^target, opts ->
      assert opts[:element] == :poison
      {:ok, %{damage: 40, is_critical: false}}
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(MobSession, :apply_damage, fn _pid, 40, 10_001 -> :ok end)

    assert :ok =
             SkillAttack.execute_skill_attack(caster_state, {:mob, target_id},
               skill_id: 7,
               skill_level: 1,
               element: :poison,
               ignore_flee: true
             )
  end

  test "magic skills are denied before magic calculation and defense effects", %{castle: castle} do
    attacker = player_combatant(7, castle)
    target = emperium_combatant(castle)
    caster_state = %TestUnit{combatant: attacker, stats: %{}, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}

    stub(GuildManager, :get, fn 7 -> {:ok, guild_state(7, %{10_000 => 1})} end)

    stub(TargetResolver, :resolve, fn {:mob, @emperium_unit_id} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    reject(&MagicDamageCalculator.calculate_magic_damage/3)

    assert MagicAttack.execute_magic_attack(caster_state, {:mob, @emperium_unit_id},
             skill_id: 19,
             skill_level: 1,
             element: :fire,
             skip_range: true
           ) == {:error, :skill_not_allowed}
  end

  test "physical skills are denied before weapon interception and damage calculation", %{
    castle: castle
  } do
    attacker = player_combatant(7, castle)
    target = emperium_combatant(castle)
    caster_state = %TestUnit{combatant: attacker, stats: %{}, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}

    stub(GuildManager, :get, fn 7 -> {:ok, guild_state(7, %{10_000 => 1})} end)

    stub(TargetResolver, :resolve, fn {:mob, @emperium_unit_id} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    reject(&StatusInterpreter.before_weapon_hit/3)
    reject(&DamageCalculator.calculate_damage/3)

    assert SkillAttack.execute_skill_attack(caster_state, {:mob, @emperium_unit_id},
             skill_id: 7,
             skill_level: 1,
             ignore_flee: true
           ) == {:error, :skill_not_allowed}
  end

  test "every normal eligibility denial precedes committed offensive effects", %{castle: castle} do
    attacker = player_combatant(7, castle)
    live_target = emperium_combatant(castle)
    stale_target = emperium_combatant(castle, @emperium_unit_id + 1)
    caster_state = %TestUnit{combatant: attacker, stats: %{}, hp: 100}
    live_state = %TestUnit{combatant: live_target, hp: 100}
    stale_state = %TestUnit{combatant: stale_target, hp: 100}

    stub(GuildManager, :get, fn 7 -> {:ok, Process.get(:task4_guild)} end)

    stub(TargetResolver, :resolve, fn
      @emperium_unit_id -> {:ok, self(), live_state, :mob}
      id when id == @emperium_unit_id + 1 -> {:ok, self(), stale_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn _target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, _target, [projectile?: true] -> :ok end)
    reject(&StatusInterpreter.on_committed_action/3)

    Process.put(:task4_guild, guild_state(7, %{}))

    assert {{:error, :approval_required}, ^caster_state} =
             AutoAttack.execute_attack(%{}, caster_state, @emperium_unit_id, &Function.identity/1)

    Process.put(:task4_guild, guild_state(7, %{10_000 => 1}))
    :ok = CastleStore.hydrate(%{castle.id => 7})

    assert {{:error, :owner_guild}, ^caster_state} =
             AutoAttack.execute_attack(%{}, caster_state, @emperium_unit_id, &Function.identity/1)

    :ok = MapFlags.set_runtime(castle.map, :gvg, false)

    assert {{:error, :siege_inactive}, ^caster_state} =
             AutoAttack.execute_attack(%{}, caster_state, @emperium_unit_id, &Function.identity/1)

    :ok = MapFlags.set_runtime(castle.map, :gvg, true)
    :ok = CastleStore.hydrate(%{castle.id => 8})

    assert {{:error, :stale_emperium}, ^caster_state} =
             AutoAttack.execute_attack(
               %{},
               caster_state,
               @emperium_unit_id + 1,
               &Function.identity/1
             )
  end

  test "guildless normal attacks are denied before committing offensive effects", %{
    castle: castle
  } do
    attacker =
      CombatTestHelper.create_player_combatant(
        unit_id: 10_001,
        position: castle.emperium,
        map_name: castle.map
      )

    target =
      CombatTestHelper.create_mob_combatant(
        unit_id: @emperium_unit_id,
        monster_id: @emperium_mob_id,
        position: castle.emperium,
        map_name: castle.map
      )

    caster_state = %TestUnit{combatant: attacker, stats: %{}, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}

    stub(TargetResolver, :resolve, fn @emperium_unit_id ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, [projectile?: true] -> :ok end)
    reject(&StatusInterpreter.on_committed_action/3)

    assert {{:error, :guild_required}, ^caster_state} =
             AutoAttack.execute_attack(%{}, caster_state, @emperium_unit_id, &Function.identity/1)
  end

  defp player_combatant(guild_id, castle) do
    CombatTestHelper.create_player_combatant(
      unit_id: 10_001,
      position: castle.emperium,
      map_name: castle.map
    )
    |> Map.merge(%{
      guild_id: guild_id,
      social_root: {:player, 10_001},
      reward_root: {:player, 10_001}
    })
  end

  defp emperium_combatant(castle, unit_id \\ @emperium_unit_id) do
    CombatTestHelper.create_mob_combatant(
      unit_id: unit_id,
      monster_id: @emperium_mob_id,
      position: castle.emperium,
      map_name: castle.map
    )
    |> Map.merge(%{social_root: {:mob, unit_id}, reward_root: nil})
  end

  defp homunculus_state(castle, owner_id, homunculus_id) do
    {x, y} = castle.emperium

    %HomunculusState{
      id: 1,
      owner_character_id: owner_id,
      class_id: 6001,
      name: "Filir",
      lifecycle: :active,
      hp: 100,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      world_gid: homunculus_id,
      map_name: castle.map,
      x: x,
      y: y
    }
  end

  defp guild_state(guild_id, learned_skills) do
    %GuildState{
      guild_id: guild_id,
      name: "Guild #{guild_id}",
      master_char_id: guild_id,
      learned_skills: learned_skills
    }
  end
end
