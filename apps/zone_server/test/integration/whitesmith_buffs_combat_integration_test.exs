defmodule Aesir.ZoneServer.Integration.WhitesmithBuffsCombatIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Mob.MobState

  test "real_buff_cast_updates_movement_and_conflicts" do
    char = character()

    {:ok, _weapon} =
      Persistence.insert_item(char.id, %{nameid: 1_101, amount: 1, identify: 1, equip: 2})

    session = start_player_session(character: char)
    on_exit(fn -> end_player_session(session) end)
    assert {:ok, _} = GenServer.call(session.pid, {:npc, {:script_apply, {:setcart, 1}}})
    caster_id = session.character.id

    assert :ok =
             PlayerSession.apply_status(session.pid, :sc_decreaseagi,
               val1: 1,
               duration: 60_000,
               no_avoid: true
             )

    cast(session, 387, 1)

    assert eventually(fn ->
             not StatusStorage.has_status?(:player, caster_id, :sc_decreaseagi)
           end)

    refute StatusStorage.has_status?(:player, caster_id, :sc_cartboost)
    cast(session, 387, 1)
    assert eventually(fn -> get_player_state(session.pid).walk_speed == 120 end)

    assert :ok =
             PlayerSession.apply_status(session.pid, :sc_increaseagi,
               val1: 1,
               val2: 3,
               duration: 60_000
             )

    assert eventually(fn -> get_player_state(session.pid).walk_speed == 112 end)
    cast(session, 113, 5)
    assert eventually(fn -> StatusStorage.has_status?(:player, caster_id, :sc_overthrust) end)
    cast(session, 486, 5)
    assert eventually(fn -> StatusStorage.has_status?(:player, caster_id, :sc_maxoverthrust) end)
    refute StatusStorage.has_status?(:player, caster_id, :sc_overthrust)
    cast(session, 113, 5)
    _settled = PlayerSession.get_state(session.pid)
    refute StatusStorage.has_status?(:player, caster_id, :sc_overthrust)
  end

  test "real_weapon_hit_breaks_or_strips_in_owning_path" do
    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :hit end)

    stub(DamageCalculator, :calculate_damage, fn _, _, _ ->
      {:ok, %{damage: 10, is_critical: false}}
    end)

    stub(Resistance, :roll_rate, fn _ -> true end)
    source = start_mob_session(position: {151, 150}, max_hp: 10_000)
    state = get_mob_state(source.pid)

    assert :ok =
             Executor.execute(state, %{
               skill_id: 384,
               skill: :ws_meltdown,
               level: 10,
               target: :self
             })

    assert %{source_type: :mob, source_id: id} =
             StatusStorage.get_status(:mob, source.unit_id, :sc_meltdown)

    assert id == source.unit_id

    for path <- [:normal, :skill] do
      char = character()

      {:ok, weapon} =
        Persistence.insert_item(char.id, %{nameid: 1_101, amount: 1, identify: 1, equip: 2})

      target = start_player_session(character: char, position: {150, 150})
      on_exit(fn -> end_player_session(target) end)
      :rand.seed(:exsss, {102, 103, 104})

      if path == :normal do
        assert :ok = Combat.execute_mob_attack(state, char.id)
      else
        assert :ok =
                 Combat.execute_skill_attack(state, {:player, char.id},
                   skill_id: 5,
                   skill_level: 1,
                   skip_crit: true,
                   ignore_flee: true,
                   skip_range: true
                 )
      end

      assert eventually(fn -> Repo.get!(InventoryItem, weapon.id).attribute == 1 end)
      assert Repo.get!(InventoryItem, weapon.id).equip == 0
    end
  end

  test "summon_and_master_status_ownership_stays_separate" do
    stub(DamageCalculator, :calculate_damage, fn _, _, _ ->
      {:ok, %{damage: 10, is_critical: false}}
    end)

    stub(Resistance, :roll_rate, fn _ -> true end)
    master = start_player_session(character: character())
    on_exit(fn -> end_player_session(master) end)
    source = start_mob_session(position: {151, 150}, max_hp: 10_000)
    victim = start_mob_session(position: {152, 150}, max_hp: 10_000)

    summon =
      MobState.configure_summon(get_mob_state(source.pid),
        owner_player_id: master.character.id,
        summon_kind: :flora
      )

    for {original?, master?} <- [{true, false}, {false, true}, {true, true}, {false, false}] do
      for {type, id, status} <- [
            {:mob, source.unit_id, :sc_meltdown},
            {:player, master.character.id, :sc_meltdown},
            {:mob, victim.unit_id, :sc_stripweapon},
            {:mob, victim.unit_id, :sc_striparmor}
          ],
          do: Interpreter.remove_status(type, id, status)

      if original?,
        do:
          Interpreter.apply_status(:mob, source.unit_id, :sc_meltdown, val1: 10, duration: 60_000)

      if master?,
        do:
          Interpreter.apply_status(:player, master.character.id, :sc_meltdown,
            val1: 10,
            duration: 60_000
          )

      :rand.seed(:exsss, {102, 103, 104})

      flag = BattleFlags.build(:weapon, :short, true)
      event = EquipProcDispatch.event(flag, 10, %{}, target_survives?: true)

      target = %{
        type: :mob,
        id: victim.unit_id,
        pid: victim.pid,
        state: get_mob_state(victim.pid)
      }

      assert :ok =
               EquipProcDispatch.dispatch_breaks(
                 MobState.to_combatant(summon),
                 target,
                 event,
                 flag,
                 5
               )

      assert StatusStorage.has_status?(:mob, victim.unit_id, :sc_stripweapon) ==
               (original? and master?)

      if original? and master? do
        assert %{source_type: :player, source_id: owner, val2: 40} =
                 StatusStorage.get_status(:mob, victim.unit_id, :sc_striparmor)

        assert owner == master.character.id

        assert eventually(fn ->
                 get_mob_state(victim.pid).calculated.vit < get_mob_state(victim.pid).base.vit
               end)
      end
    end
  end

  defp cast(session, skill, level),
    do:
      simulate_incoming_message(session.pid, %SkillCast{
        skill_id: skill,
        level: level,
        target_id: session.character.id
      })

  defp character do
    id = System.unique_integer([:positive])

    account =
      Repo.insert!(%Account{userid: "ws#{id}", user_pass: "unused", email: "ws@test.local"})

    Repo.insert!(%Character{
      account_id: account.id,
      char_num: 0,
      name: "Smith#{id}",
      class: 4011,
      base_level: 99,
      job_level: 70,
      hp: 5_000,
      max_hp: 5_000,
      sp: 500,
      max_sp: 500,
      zeny: 100_000,
      learned_skills: %{"39" => 10, "387" => 1, "486" => 5, "384" => 10, "113" => 5},
      last_map: "prontera",
      last_x: 150,
      last_y: 150
    })
  end
end
