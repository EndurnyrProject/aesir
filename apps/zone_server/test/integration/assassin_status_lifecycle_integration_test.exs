defmodule Aesir.ZoneServer.Integration.AssassinStatusLifecycleIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.PickupItemRequest
  alias Aesir.Net.PickupResult
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsCloaking
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsEnchantpoison
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsSplasher
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsVenomdust
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "assassin_lifecycle_test"
  @other_map "assassin_lifecycle_other"

  @detecting 130
  @falconry 127
  @cloaking 135
  @enchant_poison 138
  @poison_react 139
  @venom_dust 140
  @splasher 141
  @venom_knife 1_004
  @red_gemstone 716
  @venom_knife_item 1_771
  @ammo_slot 0x008000

  setup do
    cache_map(@map)
    cache_map(@other_map)
    :ok
  end

  test "Cloaking follows command, action, damage, detection, map, SP, and mob lifecycles" do
    assassin = start_assassin(%{@cloaking => 10}, {10, 10})
    assassin_id = assassin.character.id
    mob = start_real_mob(26_001, {11, 10})

    initial_sp = current_sp(assassin.pid)
    cast(assassin.pid, @cloaking, 1, assassin_id)
    refute StatusStorage.has_status?(:player, assassin_id, :sc_cloaking)
    assert current_sp(assassin.pid) == initial_sp

    cast(assassin.pid, @cloaking, 3, assassin_id)
    assert eventually(fn -> cloaking(assassin_id).state.adjacent_impassable? == false end)
    open_speed = get_player_state(assassin.pid).walk_speed

    put_wall(@map, 10, 9)
    simulate_incoming_message(assassin.pid, %MoveRequest{dest_x: 10, dest_y: 11})

    assert eventually(fn -> cloaking(assassin_id).state.adjacent_impassable? end)
    assert get_player_state(assassin.pid).walk_speed < open_speed

    simulate_incoming_message(assassin.pid, %PickupItemRequest{ground_id: 999_999})
    assert_receive {:packet_sent, %PickupResult{ground_id: 999_999, result: :FAILED}, _}, 1_000
    assert StatusStorage.has_status?(:player, assassin_id, :sc_cloaking)

    simulate_incoming_message(assassin.pid, %ActionRequest{target_id: mob.unit_id, action: 0})
    assert eventually(fn -> not StatusStorage.has_status?(:player, assassin_id, :sc_cloaking) end)

    apply_cloaking(assassin_id, 3)
    :rand.seed(:exsss, {1, 2, 3})
    assert :ok = Combat.execute_mob_attack(get_mob_state(mob.pid), assassin_id)
    assert eventually(fn -> not StatusStorage.has_status?(:player, assassin_id, :sc_cloaking) end)

    detector =
      11
      |> insert_character(%{@detecting => 4, @falconry => 1}, option: Option.id(:falcon))
      |> start_character({8, 10})

    apply_cloaking(assassin_id, 3)
    cast_ground(detector.pid, @detecting, 4, {10, 10})
    assert eventually(fn -> not StatusStorage.has_status?(:player, assassin_id, :sc_cloaking) end)

    apply_cloaking(assassin_id, 3)
    PlayerSession.warp(assassin.pid, @other_map, 10, 10)
    assert eventually(fn -> get_player_state(assassin.pid).map_name == @other_map end)
    refute StatusStorage.has_status?(:player, assassin_id, :sc_cloaking)

    PlayerSession.warp(assassin.pid, @map, 10, 10)
    assert eventually(fn -> get_player_state(assassin.pid).map_name == @map end)
    apply_cloaking(assassin_id, 3, tick: 1)
    assert :ok = PlayerSession.try_consume_sp(assassin.pid, current_sp(assassin.pid))
    make_tick_due(:player, assassin_id, :sc_cloaking)
    StatusTickManager.force_tick()
    assert eventually(fn -> not StatusStorage.has_status?(:player, assassin_id, :sc_cloaking) end)

    assert :ok =
             AsCloaking.mob_cast(
               get_mob_state(mob.pid),
               :self,
               1,
               AsCloaking.definition(),
               %{}
             )

    assert %{tick: 0, expires_at: expires_at} = cloaking(:mob, mob.unit_id)
    assert_in_delta expires_at - System.monotonic_time(:millisecond), 10_000, 100
    make_expired(:mob, mob.unit_id, :sc_cloaking)
    StatusTickManager.force_tick()
    assert eventually(fn -> not StatusStorage.has_status?(:mob, mob.unit_id, :sc_cloaking) end)
  end

  test "same-party Enchant Poison commits a typed endow and ordinary-hit proc only for valid targets" do
    caster_character = insert_character(12, %{@enchant_poison => 10}, [])
    ally_character = insert_character(12, %{}, [])
    party_name = "Poison#{System.unique_integer([:positive])}"
    assert {:ok, party} = PartyManager.create(party_name, caster_character)
    assert {:ok, _party} = PartyManager.add_member(party.party_id, ally_character)

    caster = start_character(Repo.get!(Character, caster_character.id), {10, 20})
    ally = start_character(Repo.get!(Character, ally_character.id), {11, 20})
    outsider = start_assassin(%{}, {11, 21})
    mob = start_real_mob(26_101, {12, 20}, agi: 1)

    assert get_player_state(caster.pid).party_id == party.party_id
    assert get_player_state(ally.pid).party_id == party.party_id

    assert :ok =
             AsEnchantpoison.validate(
               get_player_state(caster.pid),
               {:unit, ally.character.id},
               10,
               AsEnchantpoison.definition()
             )

    caster_sp = current_sp(caster.pid)
    cast(caster.pid, @enchant_poison, 10, ally.character.id)

    assert %{source_id: source_id, source_type: :player} =
             StatusStorage.get_status(:player, ally.character.id, :sc_encpoison)

    assert source_id == caster.character.id

    assert StatusInterpreter.get_all_modifiers(:player, ally.character.id).attack_element ==
             :poison

    assert current_sp(caster.pid) == caster_sp - 20

    :ok =
      StatusStorage.update_status(:player, ally.character.id, :sc_encpoison, fn status ->
        %{status | val1: 195}
      end)

    seed_session_rng(ally.pid, {11, 22, 33})
    simulate_incoming_message(ally.pid, %ActionRequest{target_id: mob.unit_id, action: 0})

    assert eventually(fn -> StatusStorage.has_status?(:mob, mob.unit_id, :sc_poison) end)

    assert %{source_id: ally_id, source_type: :player} =
             StatusStorage.get_status(:mob, mob.unit_id, :sc_poison)

    assert ally_id == ally.character.id

    sp_before_rejection = current_sp(caster.pid)
    cast(caster.pid, @enchant_poison, 10, outsider.character.id)
    assert current_sp(caster.pid) == sp_before_rejection
    refute StatusStorage.has_status?(:player, outsider.character.id, :sc_encpoison)
  end

  test "real MobSession attacks drive both Poison React branches without a session deadlock" do
    holder = start_assassin(%{@poison_react => 10}, {20, 20})
    holder_id = holder.character.id
    neutral_mob = start_real_mob(26_201, {21, 20}, agi: 1)

    arm_poison_react(holder_id, 2)
    set_poison_react_chance(holder_id, 100)
    mob_hp = get_mob_state(neutral_mob.pid).hp

    assert is_integer(drive_mob_attack(neutral_mob, holder))

    assert eventually(fn ->
             not StatusStorage.has_status?(:player, holder_id, :sc_poisonreact)
           end)

    assert eventually(fn -> get_mob_state(neutral_mob.pid).hp < mob_hp end)
    assert_sessions_responsive(holder.pid, neutral_mob.pid)

    poison_mob = start_real_mob(26_202, {21, 20}, agi: 1)
    set_mob_element(poison_mob, {:poison, 1})
    arm_poison_react(holder_id, 6)
    holder_hp = get_player_state(holder.pid).stats.current_state.hp
    poison_mob_hp = get_mob_state(poison_mob.pid).hp

    assert is_integer(drive_mob_attack(poison_mob, holder))

    assert eventually(fn ->
             not StatusStorage.has_status?(:player, holder_id, :sc_poisonreact)
           end)

    assert get_player_state(holder.pid).stats.current_state.hp == holder_hp
    assert eventually(fn -> get_mob_state(poison_mob.pid).hp < poison_mob_hp end)
    assert_sessions_responsive(holder.pid, poison_mob.pid)
  end

  test "Venom Dust commits one catalyst and the real manager owns overlap, poison, metadata, mob placement, and expiry" do
    caster_character = insert_character(12, %{@venom_dust => 10}, [])
    seed_item(caster_character.id, @red_gemstone, 1)
    caster = start_character(caster_character, {29, 30})
    target = start_real_mob(26_301, {30, 30})
    already_poisoned = start_real_mob(26_302, {31, 31})

    assert :ok =
             StatusInterpreter.apply_status(:mob, already_poisoned.unit_id, :sc_poison,
               duration: 60_000,
               loaded: true
             )

    existing_poison =
      StatusStorage.get_status(:mob, already_poisoned.unit_id, :sc_poison).generation

    cast_ground(caster.pid, @venom_dust, 1, {30, 30})
    group = find_skill_group(:as_venomdust)

    assert Enum.sort(group.cells) ==
             Enum.sort([{30, 30}, {29, 30}, {31, 30}, {30, 29}, {30, 31}])

    assert group.state.removed_by_fire_rain
    assert Inventory.held_amount(get_player_state(caster.pid).inventory, @red_gemstone) == 0

    manager = start_manual_skill_unit_manager()
    assert :ok = SkillUnitManager.tick(manager, group.next_tick_at)

    assert %{source_id: source_id, source_type: :player} =
             StatusStorage.get_status(:mob, target.unit_id, :sc_poison)

    assert source_id == caster.character.id

    assert StatusStorage.get_status(:mob, already_poisoned.unit_id, :sc_poison).generation ==
             existing_poison

    rejected_character = insert_character(12, %{@venom_dust => 1}, [])
    seed_item(rejected_character.id, @red_gemstone, 1)
    rejected = start_character(rejected_character, {29, 31})
    cast_ground(rejected.pid, @venom_dust, 1, {30, 30})

    assert Inventory.held_amount(get_player_state(rejected.pid).inventory, @red_gemstone) == 1
    assert Enum.count(SkillUnitStorage.all(), &(&1.skill_name == :as_venomdust)) == 1

    mob_caster = start_real_mob(26_303, {9, 35}, mob_id: 2_783)

    assert {:ok, _mob_state} =
             AsVenomdust.cast_with_origin(
               get_mob_state(mob_caster.pid),
               {:ground, 10, 35},
               4,
               AsVenomdust.definition(),
               :mob
             )

    assert Enum.any?(SkillUnitStorage.all(), &(&1.caster_type == :mob))

    assert :ok = SkillUnitManager.tick(manager, group.expires_at)
    assert SkillUnitStorage.get(group.group_id) == nil
  end

  test "Splasher exact generations follow moving targets and stale death, warp, replacement, and missing-source cleanup never explode" do
    caster = start_assassin(%{@splasher => 10, @poison_react => 7}, {20, 10})
    target = start_real_mob(26_401, {21, 10})

    cast_and_complete(caster.pid, @splasher, 10, target.unit_id)

    assert %{state: %{remaining_ms: 2_000, poison_react_level: 7}} =
             armed = StatusStorage.get_status(:mob, target.unit_id, :sc_splasher)

    move_mob_now(target, {25, 10})
    hp_before = get_mob_state(target.pid).hp
    backdated_start = System.monotonic_time(:millisecond) - 20_000

    :ok =
      StatusStorage.update_status(:mob, target.unit_id, :sc_splasher, fn status ->
        %{status | started_at: backdated_start}
      end)

    first_due = backdated_start + 1_000

    assert drive_exact_ticks(:mob, target.unit_id, armed.generation, first_due) ==
             backdated_start + 2_500

    refute StatusStorage.has_status?(:mob, target.unit_id, :sc_splasher)
    assert eventually(fn -> get_mob_state(target.pid).hp < hp_before end)

    dying = start_real_mob(26_402, {21, 10}, hp: 1, max_hp: 1)
    arm_splasher(caster, :mob, dying.unit_id, 10)
    dying_generation = splasher_generation(:mob, dying.unit_id)
    MobSession.apply_damage(dying.pid, 1, {:player, caster.character.id})
    assert eventually(fn -> not StatusStorage.has_status?(:mob, dying.unit_id, :sc_splasher) end)
    assert tick_current(:mob, dying.unit_id, dying_generation, 1) == :stop

    warped = start_assassin(%{}, {21, 11})
    arm_splasher(caster, :player, warped.character.id, 10)
    warped_generation = splasher_generation(:player, warped.character.id)
    PlayerSession.warp(warped.pid, @other_map, 5, 5)
    assert eventually(fn -> get_player_state(warped.pid).map_name == @other_map end)
    refute StatusStorage.has_status?(:player, warped.character.id, :sc_splasher)
    assert tick_current(:player, warped.character.id, warped_generation, 1) == :stop

    replacement = start_real_mob(26_403, {21, 10})
    arm_splasher(caster, :mob, replacement.unit_id, 10)
    old_generation = splasher_generation(:mob, replacement.unit_id)
    arm_splasher(caster, :mob, replacement.unit_id, 9)
    new_generation = splasher_generation(:mob, replacement.unit_id)
    assert new_generation > old_generation
    assert tick_current(:mob, replacement.unit_id, old_generation, 1) == :stop
    assert StatusStorage.has_status?(:mob, replacement.unit_id, :sc_splasher)

    gaster = start_real_mob(26_404, {20, 12}, mob_id: 3_740)
    imported_target = start_real_mob(26_405, {21, 12})
    assert {:ok, _mob} = arm_splasher(gaster, :mob, imported_target.unit_id, 5)
    imported_generation = splasher_generation(:mob, imported_target.unit_id)
    :ok = UnitRegistry.unregister_unit(:mob, gaster.unit_id)
    assert tick_until_stopped(:mob, imported_target.unit_id, imported_generation) == :stop
    refute StatusStorage.has_status?(:mob, imported_target.unit_id, :sc_splasher)
  end

  test "Venom Knife uses equipped ammo, reports one damage channel, bypasses Auto Guard, and Poisons" do
    armed_character = insert_character(12, %{@venom_knife => 1}, [])
    seed_item(armed_character.id, @venom_knife_item, 2, @ammo_slot)
    armed = start_character(armed_character, {5, 5})
    target = start_real_mob(26_501, {6, 5}, agi: 1)

    assert :ok =
             StatusInterpreter.apply_status(:mob, target.unit_id, :sc_autoguard,
               val1: 10,
               val2: 100,
               duration: 60_000,
               loaded: true
             )

    seed_session_rng(armed.pid, {1, 2, 3})
    hp_before = get_mob_state(target.pid).hp
    sp_before = current_sp(armed.pid)
    cast(armed.pid, @venom_knife, 1, target.unit_id)
    assert current_sp(armed.pid) == sp_before - 35

    assert eventually(fn -> get_mob_state(target.pid).hp < hp_before end)
    damage = hp_before - get_mob_state(target.pid).hp
    assert damage > 0
    assert StatusStorage.has_status?(:mob, target.unit_id, :sc_autoguard)
    assert StatusStorage.has_status?(:mob, target.unit_id, :sc_poison)
    assert inventory_amount(armed.pid, @venom_knife_item) == 1

    unarmed = start_assassin(%{@venom_knife => 1}, {5, 6})
    sp_before = current_sp(unarmed.pid)
    hp_before_rejection = get_mob_state(target.pid).hp
    cast(unarmed.pid, @venom_knife, 1, target.unit_id)
    assert current_sp(unarmed.pid) == sp_before
    assert get_mob_state(target.pid).hp == hp_before_rejection
  end

  defp cast(pid, skill_id, level, target_id) do
    simulate_incoming_message(pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id
    })

    _sync = get_player_state(pid)
    :ok
  end

  defp cast_and_complete(pid, skill_id, level, target_id) do
    simulate_incoming_message(pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id
    })

    raw_state = GenServer.call(pid, :get_state)
    send(pid, {:skill, {:cast_complete, raw_state.game_state.casting.token}})
    _sync = get_player_state(pid)
    :ok
  end

  defp arm_splasher(source, _target_type, target_id, level) do
    source_state =
      if Map.has_key?(source, :character),
        do: get_player_state(source.pid),
        else: get_mob_state(source.pid)

    AsSplasher.cast(source_state, {:unit, target_id}, level, AsSplasher.definition())
  end

  defp splasher_generation(type, id) do
    StatusStorage.get_status(type, id, :sc_splasher).generation
  end

  defp tick_current(type, id, generation, count) do
    Enum.reduce(1..count, nil, fn _, _result ->
      StatusInterpreter.process_tick_if_current(type, id, :sc_splasher, generation)
    end)
  end

  defp drive_exact_ticks(type, id, generation, due_at) do
    state = %StatusTickManager.State{}

    assert {:noreply, ^state} =
             StatusTickManager.handle_cast(
               {:schedule_exact_tick, type, id, :sc_splasher, generation, due_at},
               state
             )

    assert_receive {:exact_status_tick, ^type, ^id, :sc_splasher, ^generation, ^due_at} =
                     message

    drive_exact_tick_messages(message, state)
  end

  defp drive_exact_tick_messages(
         {:exact_status_tick, type, id, :sc_splasher, generation, due_at} = message,
         state
       ) do
    assert {:noreply, ^state} = StatusTickManager.handle_info(message, state)

    if StatusStorage.has_status?(type, id, :sc_splasher) do
      next_due = due_at + 500

      assert_receive {:exact_status_tick, ^type, ^id, :sc_splasher, ^generation, ^next_due} =
                       next_message

      drive_exact_tick_messages(next_message, state)
    else
      due_at
    end
  end

  defp tick_until_stopped(type, id, generation) do
    case StatusInterpreter.process_tick_if_current(type, id, :sc_splasher, generation) do
      :continue -> tick_until_stopped(type, id, generation)
      :stop -> :stop
    end
  end

  defp move_mob_now(mob, {x, y}) do
    updated = :sys.replace_state(mob.pid, &%{&1 | x: x, y: y})
    :ok = UnitRegistry.update_unit_state(:mob, mob.unit_id, updated)
    :ok = SpatialIndex.update_unit_position(:mob, mob.unit_id, x, y, @map)
  end

  defp cast_ground(pid, skill_id, level, {x, y}) do
    simulate_incoming_message(pid, %GroundSkillCast{skill_id: skill_id, level: level, x: x, y: y})
    _sync = get_player_state(pid)
    :ok
  end

  defp find_skill_group(skill_name) do
    assert eventually(fn -> Enum.any?(SkillUnitStorage.all(), &(&1.skill_name == skill_name)) end)
    Enum.find(SkillUnitStorage.all(), &(&1.skill_name == skill_name))
  end

  defp start_manual_skill_unit_manager do
    start_supervised!(
      {SkillUnitManager, name: nil, schedule_tick: fn _pid, _interval -> :ok end},
      id: make_ref()
    )
  end

  defp apply_cloaking(player_id, level, opts \\ []) do
    StatusInterpreter.apply_status(
      :player,
      player_id,
      :sc_cloaking,
      Keyword.merge(
        [
          val1: level,
          caster_id: player_id,
          source_type: :player,
          duration: 60_000,
          state: %{adjacent_impassable?: false}
        ],
        opts
      )
    )
  end

  defp cloaking(player_id), do: cloaking(:player, player_id)
  defp cloaking(type, id), do: StatusStorage.get_status(type, id, :sc_cloaking)

  defp make_tick_due(type, id, status_id) do
    now = System.monotonic_time(:millisecond)

    StatusStorage.update_status(type, id, status_id, fn status ->
      %{status | next_tick_at: now - 1, expires_at: now + 60_000}
    end)
  end

  defp make_expired(type, id, status_id) do
    now = System.monotonic_time(:millisecond)

    StatusStorage.update_status(type, id, status_id, fn status ->
      %{status | next_tick_at: now - 1, expires_at: now - 1}
    end)
  end

  defp arm_poison_react(holder_id, level) do
    StatusInterpreter.apply_status(:player, holder_id, :sc_poisonreact,
      val1: level,
      duration: 60_000,
      caster_id: holder_id,
      source_type: :player
    )
  end

  defp set_poison_react_chance(holder_id, chance) do
    StatusStorage.update_status(:player, holder_id, :sc_poisonreact, fn status ->
      put_in(status.state.chance, chance)
    end)
  end

  defp set_mob_element(mob, element) do
    updated =
      :sys.replace_state(mob.pid, fn state ->
        %{state | mob_data: %{state.mob_data | element: element}}
      end)

    :ok = UnitRegistry.update_unit_state(:mob, mob.unit_id, updated)
  end

  defp assert_sessions_responsive(player_pid, mob_pid) do
    assert %{game_state: %{}} = GenServer.call(player_pid, :get_state, 250)
    assert %{} = GenServer.call(mob_pid, :get_state, 250)
  end

  defp seed_session_rng(pid, seed) do
    :sys.replace_state(pid, fn state ->
      :rand.seed(:exsss, seed)
      state
    end)
  end

  defp drive_mob_attack(mob, target) do
    updated =
      :sys.replace_state(mob.pid, fn state ->
        if state.ai_timer_ref, do: Process.cancel_timer(state.ai_timer_ref)
        :rand.seed(:exsss, {101, 202, 303})

        state
        |> Map.put(:ai_awake, true)
        |> Map.put(:spawn_tick_pending?, false)
        |> Map.put(:last_attack_time, nil)
        |> Map.put(:target_ref, {:player, target.character.id})
        |> Map.put(:ai_state, :combat)
      end)

    :ok = UnitRegistry.update_unit_state(:mob, mob.unit_id, updated)
    send(mob.pid, {:ai, :tick})
    attacked = get_mob_state(mob.pid)
    MobSession.sleep(mob.pid)
    _sync = get_mob_state(mob.pid)
    attacked.last_attack_time
  end

  defp start_assassin(skills, position, opts \\ []) do
    12
    |> insert_character(skills, opts)
    |> start_character(position)
  end

  defp start_character(character, {x, y} = position) do
    session = start_player_session(character: character, map_name: @map, position: position)

    raw =
      :sys.replace_state(session.pid, fn raw ->
        game_state = %{raw.game_state | x: x, y: y, map_name: @map}
        %{raw | game_state: game_state}
      end)

    :ok = UnitRegistry.update_unit_state(:player, character.id, raw.game_state)
    :ok = SpatialIndex.update_unit_position(:player, character.id, x, y, @map)
    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp seed_item(character_id, nameid, amount, equip \\ 0) do
    assert {:ok, _item} =
             InventoryPersistence.insert_item(character_id, %{
               nameid: nameid,
               amount: amount,
               equip: equip,
               identify: 1
             })
  end

  defp start_real_mob(id, position, opts \\ []) do
    mob =
      start_mob_session(
        Keyword.merge(
          [
            unit_id: id,
            mob_id: 999_999,
            map_name: @map,
            position: position,
            hp: 100_000,
            max_hp: 100_000,
            dex: 999
          ],
          opts
        )
      )

    on_exit(fn -> end_mob_session(mob) end)
    mob
  end

  defp insert_character(class, skills, opts) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "assassinlife#{uniq}",
        userid: "assassinlife#{uniq}",
        user_pass: "password",
        email: "assassinlife#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs = %{
      account_id: account.id,
      char_num: 0,
      name: "AssassinLife#{uniq}",
      class: class,
      base_level: 80,
      job_level: 50,
      str: 80,
      agi: 80,
      vit: 40,
      int: 10,
      dex: 99,
      luk: 40,
      max_hp: 20_000,
      hp: 20_000,
      max_sp: 2_000,
      sp: Keyword.get(opts, :sp, 2_000),
      party_id: Keyword.get(opts, :party_id, 0),
      option: Keyword.get(opts, :option, 0),
      learned_skills: Map.new(skills, fn {id, level} -> {Integer.to_string(id), level} end),
      last_map: @map,
      last_x: 10,
      last_y: 10,
      save_map: @map,
      save_x: 10,
      save_y: 10
    }

    {:ok, character} = %Character{} |> Character.changeset(attrs) |> Repo.insert()
    character
  end

  defp cache_map(name) do
    map = MapData.new(name, 40, 40)
    :ets.insert(EtsTable.table_for(:map_cache), {name, map})
  end

  defp put_wall(map_name, x, y) do
    {:ok, map} = Aesir.ZoneServer.Map.MapCache.get(map_name)
    updated = MapData.set_cell(map, x, y, GatType.wall())
    :ets.insert(EtsTable.table_for(:map_cache), {map_name, updated})
  end

  defp inventory_amount(pid, nameid) do
    pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Map.values()
    |> Enum.find(&(&1.nameid == nameid))
    |> Map.fetch!(:amount)
  end

  defp current_sp(pid), do: get_player_state(pid).stats.current_state.sp
end
