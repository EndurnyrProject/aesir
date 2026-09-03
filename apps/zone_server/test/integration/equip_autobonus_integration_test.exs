defmodule Aesir.ZoneServer.Integration.EquipAutobonusIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillCast
  alias Aesir.Net.UnequipItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "prontera"
  @armor 16
  @attacker_item 990_001
  @defender_item 990_002
  @combat_item 990_003
  @skill_item 990_004
  @lifecycle_item 990_005
  @heal 28
  @duration 60_000

  setup do
    Mimic.copy(ItemManagement)
    Mimic.copy(StatusInterpreter)
    items = item_definitions()

    stub(ItemManagement, :get_item_by_id, fn item_id ->
      case Map.fetch(items, item_id) do
        {:ok, item} -> {:ok, item}
        :error -> call_original(ItemManagement, :get_item_by_id, [item_id])
      end
    end)

    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "normal attack activates attacker and defender registrations in their owning sessions" do
    attacker_character = insert_character("ProcAtk", %{dex: 99, luk: 0})
    defender_character = insert_character("ProcDef", %{agi: 0, luk: 0})
    attacker_row = seed_item(attacker_character.id, @attacker_item)
    defender_row = seed_item(defender_character.id, @defender_item)

    attacker = start_session(attacker_character, {150, 150})
    defender = start_session(defender_character, {151, 150})
    attacker_key = {attacker_row.id, 0}
    defender_key = {defender_row.id, 0}
    attacker_state = get_player_state(attacker.pid)
    defender_state = get_player_state(defender.pid)
    base_atk = attacker_state.stats.combat_stats.atk

    assert Map.keys(attacker_state.stats.equip_autobonuses) == [attacker_key]
    assert attacker_state.stats.active_autobonuses == %{}
    assert Map.keys(defender_state.stats.equip_autobonuses) == [defender_key]
    assert defender_state.stats.active_autobonuses == %{}

    :ok = MapFlags.set_runtime(@map, :pvp, true)

    try do
      assert :ok =
               Combat.execute_attack(
                 PlayerSession.get_current_stats(attacker.pid),
                 get_player_state(attacker.pid),
                 defender.character.id
               )

      assert eventually(fn ->
               state = get_player_state(attacker.pid)

               Map.keys(state.stats.active_autobonuses) == [attacker_key] and
                 state.stats.combat_stats.atk == base_atk + 5
             end)

      assert eventually(fn -> active_keys(defender.pid) == [defender_key] end)
    after
      MapFlags.clear_runtime(@map, :pvp)
    end

    index = inventory_index(attacker.pid, attacker_row.id)

    simulate_incoming_message(attacker.pid, %UnequipItem{
      index: PlayerState.client_index(index)
    })

    assert eventually(fn ->
             state = get_player_state(attacker.pid)

             state.stats.equip_autobonuses == %{} and state.stats.active_autobonuses == %{} and
               state.stats.combat_stats.atk == base_atk
           end)
  end

  test "physical, misc, direct magic, and ground magic hits activate only matching registrations once" do
    character = insert_character("ProcCombat", %{dex: 99, luk: 0})
    row = seed_item(character.id, @combat_item)
    session = start_session(character, {150, 150})
    mob = start_target_mob()
    test_pid = self()

    expect(StatusInterpreter, :apply_status, 4, fn unit_type, unit_id, status, params ->
      send(test_pid, {:secondary_effect, status})
      call_original(StatusInterpreter, :apply_status, [unit_type, unit_id, status, params])
    end)

    physical_key = {row.id, 0}
    misc_key = {row.id, 1}
    magic_key = {row.id, 2}
    wrong_key = {row.id, 3}

    state = get_player_state(session.pid)

    assert :ok =
             Combat.execute_skill_attack(state, mob.unit_id,
               skill_id: 5,
               skill_level: 1,
               ignore_flee: true,
               display_hit_count: 5
             )

    assert eventually(fn -> active_keys(session.pid) == [physical_key] end)
    assert_receive {:secondary_effect, :sc_summer}

    state = get_player_state(session.pid)
    assert StatusStorage.has_status?(:player, character.id, :sc_summer)

    assert :ok =
             Combat.execute_misc_attack(state, mob.unit_id,
               skill_id: 122,
               skill_level: 1,
               base_damage: 10
             )

    assert eventually(fn -> Enum.sort(active_keys(session.pid)) == [physical_key, misc_key] end)
    assert_receive {:secondary_effect, :sc_strangelights}

    state = get_player_state(session.pid)
    assert StatusStorage.has_status?(:player, character.id, :sc_strangelights)

    assert {:ok, {:mob, mob.unit_id}} ==
             Combat.execute_magic_attack(state, mob.unit_id,
               skill_id: 19,
               skill_level: 1,
               hit_count: 2
             )

    assert eventually(fn ->
             Enum.sort(active_keys(session.pid)) == [physical_key, misc_key, magic_key]
           end)

    assert_receive {:secondary_effect, :sc_moonstar}
    direct_generation = active_generation(session.pid, magic_key)
    assert StatusStorage.has_status?(:player, character.id, :sc_moonstar)
    caster = session.pid |> get_player_state() |> PlayerState.to_combatant()

    assert :ok =
             Combat.apply_skill_unit_damage(
               caster,
               :mob,
               mob.unit_id,
               89,
               1,
               :water,
               100,
               hit_divisions: 3
             )

    assert eventually(fn -> active_generation(session.pid, magic_key) != direct_generation end)
    assert_receive {:secondary_effect, :sc_moonstar}
    refute wrong_key in active_keys(session.pid)
  end

  test "only successful ordinary named skill use activates autobonus3" do
    character =
      insert_character("ProcSkill", %{
        hp: 1,
        learned_skills: %{Integer.to_string(@heal) => 1}
      })

    row = seed_item(character.id, @skill_item)
    session = start_session(character, {150, 150})
    key = {row.id, 0}

    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: @heal,
      level: 2,
      target_id: character.id
    })

    refute key in active_keys(session.pid)

    before_ordinary_hp = get_player_state(session.pid).stats.current_state.hp

    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: @heal,
      level: 1,
      target_id: character.id
    })

    assert eventually(fn ->
             state = get_player_state(session.pid)

             key in Map.keys(state.stats.active_autobonuses) and
               state.stats.current_state.hp > before_ordinary_hp
           end)

    before_state = get_player_state(session.pid)
    before_hp = before_state.stats.current_state.hp
    before_sp = before_state.stats.current_state.sp
    generation = Map.fetch!(before_state.stats.active_autobonuses, key)

    GenServer.cast(session.pid, {:skill, {:proc_cast, @heal, 1, :self}})

    assert eventually(fn ->
             state = get_player_state(session.pid)

             state.stats.current_state.hp > before_hp and
               state.stats.current_state.sp == before_sp - 13 and
               Map.fetch!(state.stats.active_autobonuses, key) == generation
           end)
  end

  test "primary and secondary effects refresh, survive death, and honor generation expiry" do
    character = insert_character("ProcLife", %{dex: 99, luk: 0})
    row = seed_item(character.id, @lifecycle_item)
    session = start_session(character, {150, 150})
    mob = start_target_mob()
    key = {row.id, 0}
    base_atk = get_player_state(session.pid).stats.combat_stats.atk
    test_pid = self()

    expect(StatusInterpreter, :apply_status, 2, fn unit_type, unit_id, status, params ->
      send(test_pid, {:secondary_effect, status})
      call_original(StatusInterpreter, :apply_status, [unit_type, unit_id, status, params])
    end)

    assert :ok =
             Combat.execute_attack(
               PlayerSession.get_current_stats(session.pid),
               get_player_state(session.pid),
               mob.unit_id
             )

    assert eventually(fn ->
             state = get_player_state(session.pid)

             Map.has_key?(state.stats.active_autobonuses, key) and
               state.stats.combat_stats.atk == base_atk + 25 and
               state.stats.modifiers.equipment.atk == 25
           end)

    assert_receive {:secondary_effect, :sc_summer}
    first_generation = active_generation(session.pid, key)
    assert StatusStorage.has_status?(:player, character.id, :sc_summer)
    registration = get_player_state(session.pid).stats.equip_autobonuses[key]

    GenServer.cast(
      session.pid,
      {:equip_autobonus_activate, key, registration.source_identity}
    )

    assert eventually(fn -> active_generation(session.pid, key) != first_generation end)
    assert_receive {:secondary_effect, :sc_summer}
    current_generation = active_generation(session.pid, key)

    send(session.pid, {:equip_autobonus_expire, key, first_generation})
    assert active_generation(session.pid, key) == current_generation
    assert get_player_state(session.pid).stats.combat_stats.atk == base_atk + 25

    PlayerSession.apply_damage(session.pid, 1_000_000, nil)

    assert eventually(fn ->
             state = get_player_state(session.pid)

             state.action_state == :dead and
               state.stats.active_autobonuses == %{key => current_generation} and
               state.stats.combat_stats.atk == base_atk + 25
           end)

    send(session.pid, {:equip_autobonus_expire, key, current_generation})

    assert eventually(fn ->
             state = get_player_state(session.pid)
             state.stats.active_autobonuses == %{} and state.stats.combat_stats.atk == base_atk
           end)
  end

  defp item_definitions do
    normal_flag = BattleFlags.build(:weapon, :short, false)

    %{
      @attacker_item => proc_item(@attacker_item, :attack, normal_flag, [{:bonus, :atk, 5}]),
      @defender_item => proc_item(@defender_item, :when_hit, normal_flag, [{:bonus, :def, 7}]),
      @combat_item => combat_proc_item(),
      @skill_item => proc_item(@skill_item, {:on_skill, @heal}, 0, [{:bonus, :atk, 11}]),
      @lifecycle_item =>
        proc_item(
          @lifecycle_item,
          :attack,
          normal_flag,
          [{:bonus, :atk, 25}],
          [{:status_start, :sc_summer, @duration, 1}]
        )
    }
  end

  defp combat_proc_item do
    registrations = [
      registration(
        :attack,
        BattleFlags.build(:weapon, :short, true),
        [],
        [{:status_start, :sc_summer, @duration, 1}]
      ),
      registration(
        :attack,
        BattleFlags.build(:misc, :long, true),
        [],
        [{:status_start, :sc_strangelights, @duration, 1}]
      ),
      registration(
        :attack,
        BattleFlags.build(:magic, :long, true),
        [],
        [{:status_start, :sc_moonstar, @duration, 1}]
      ),
      registration(
        :attack,
        BattleFlags.build(:weapon, :short, false),
        [],
        [{:status_start, :sc_super_star, @duration, 1}]
      )
    ]

    item(@combat_item, registrations)
  end

  defp proc_item(id, trigger, battle_flag, primary, secondary \\ []) do
    item(id, [registration(trigger, battle_flag, primary, secondary)])
  end

  defp registration(trigger, battle_flag, primary, secondary) do
    {:autobonus,
     %{
       trigger: trigger,
       battle_flag: battle_flag,
       primary: primary,
       secondary: secondary
     }, 1_000, @duration}
  end

  defp item(id, program) do
    %ItemDefinition{
      id: id,
      aegis_name: "PROC_ITEM_#{id}",
      name: "Proc Item #{id}",
      type: :armor,
      locations: [:armor],
      on_equip: program
    }
  end

  defp start_session(character, position) do
    session = start_player_session(character: character, map_name: @map, position: position)
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp insert_character(name, attrs) do
    unique = System.unique_integer([:positive]) |> Integer.to_string(36)
    userid = "proc#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(
        Map.merge(
          %{
            account_id: account.id,
            char_num: 0,
            name: "#{name}#{unique}",
            class: 4,
            base_level: 99,
            job_level: 50,
            str: 50,
            agi: 10,
            vit: 10,
            int: 50,
            dex: 50,
            luk: 10,
            hp: 100_000,
            max_hp: 100_000,
            sp: 10_000,
            max_sp: 10_000,
            last_map: @map,
            last_x: 150,
            last_y: 150,
            save_map: @map,
            save_x: 150,
            save_y: 150,
            learned_skills: %{}
          },
          attrs
        )
      )
      |> Repo.insert()

    character
  end

  defp start_target_mob do
    mob =
      start_mob_session(
        map_name: @map,
        position: {151, 150},
        hp: 1_000_000,
        max_hp: 1_000_000,
        agi: 0,
        luk: 0
      )

    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)
    mob
  end

  defp seed_item(character_id, item_id) do
    {:ok, row} =
      InventoryPersistence.insert_item(character_id, %{
        nameid: item_id,
        amount: 1,
        identify: 1,
        equip: @armor
      })

    row
  end

  defp active_keys(pid) do
    pid
    |> get_player_state()
    |> then(&Map.keys(&1.stats.active_autobonuses))
  end

  defp active_generation(pid, key) do
    pid
    |> get_player_state()
    |> then(&Map.get(&1.stats.active_autobonuses, key))
  end

  defp inventory_index(pid, row_id) do
    pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Enum.find_value(fn {index, item} -> if item.id == row_id, do: index end)
  end
end
