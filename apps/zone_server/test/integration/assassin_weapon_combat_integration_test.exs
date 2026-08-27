defmodule Aesir.ZoneServer.Integration.AssassinWeaponCombatIntegrationTest do
  @moduledoc """
  Production-session coverage for Assassin hand-aware weapon combat.
  """

  use Aesir.ZoneServer.IntegrationCase
  use Mimic

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.EquipItem
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AutoAttack
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.Combat.HpDrain
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DevotedBy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @assassin 12
  @crusader 14
  @knife 1201
  @knife_slotted 1202
  @jur 1250
  @vanargandr_helm 18_652
  @right_hand 2
  @left_hand 32
  @both_hands 34
  @head_top 256
  @tf_double 48
  @tf_poison 52
  @as_right 132
  @as_left 133
  @as_katar 134
  @as_enchantpoison 138
  @as_poisonreact 139

  setup do
    previous = Application.get_env(:zone_server, :natural_break_rate)
    Application.put_env(:zone_server, :natural_break_rate, 0)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:zone_server, :natural_break_rate)
      else
        Application.put_env(:zone_server, :natural_break_rate, previous)
      end
    end)

    :ok
  end

  test "real equip requests publish right, left, dual-dagger, and Katar snapshots" do
    player = start_assassin(items: [@knife, @knife_slotted, @jur], luk: 30)
    base_critical = player_state(player).stats.combat_stats.critical

    equip!(player, @knife, @right_hand)
    state = player_state(player)
    assert state.stats.right_hand.item_id == @knife
    assert state.stats.right_hand.slot == :right_hand
    assert state.stats.left_hand == nil

    unequip_all!(player)
    equip!(player, @knife, @left_hand)
    state = player_state(player)
    assert state.stats.right_hand == nil
    assert state.stats.left_hand.item_id == @knife
    assert state.stats.left_hand.slot == :left_hand

    equip!(player, @knife_slotted, @right_hand)
    state = player_state(player)
    assert state.stats.right_hand.item_id == @knife_slotted
    assert state.stats.left_hand.item_id == @knife
    assert state.stats.combat_stats.atk > 0

    equip!(player, @jur, @both_hands)
    state = player_state(player)
    assert state.stats.right_hand.item_id == @jur
    assert state.stats.right_hand.subtype == :katar
    assert state.stats.left_hand == nil
    assert state.stats.combat_stats.critical == base_critical * 2
  end

  test "normal, Double Attack, dual-dagger, and Katar packets equal real mob HP loss" do
    cases = [
      {:normal, [right: @knife], %{}},
      {:double_attack, [right: @knife], %{@tf_double => 10}},
      {:dual_dagger, [right: @knife, left: @knife_slotted], mastery_skills()},
      {:katar, [both: @jur], %{@tf_double => 10, @as_katar => 10}}
    ]

    Enum.each(cases, fn {name, equipment, skills} ->
      player = start_assassin(equipped: equipment, skills: skills)
      mob = start_target(unique_id(), race: :formless)

      {packet, hp_loss} = landed_swing(player, mob, name == :double_attack)

      assert hp_loss == packet.damage + packet.damage2
      assert packet.src_id == player.character.id
      assert packet.target_id == mob.unit_id

      if name == :double_attack do
        assert packet.div == 2
        assert packet.damage2 == 0
      end
    end)
  end

  test "masteries, proc-scoped HIT, Katar critical, plant suppression, and primary-only skills use real combatants" do
    unmastered = start_assassin(equipped: [right: @knife, left: @knife_slotted])

    mastered =
      start_assassin(equipped: [right: @knife, left: @knife_slotted], skills: mastery_skills())

    target = start_target(unique_id(), race: :formless)

    assert Passives.right_hand_damage_rate(player_state(unmastered)) == 50
    assert Passives.left_hand_damage_rate(player_state(unmastered)) == 30
    assert Passives.right_hand_damage_rate(player_state(mastered)) == 100
    assert Passives.left_hand_damage_rate(player_state(mastered)) == 80

    :rand.seed(:exsss, {17, 19, 23})
    unmastered_swing = calculated_hit(unmastered, target, rng: fn _ -> 100 end)
    :rand.seed(:exsss, {17, 19, 23})
    mastered_swing = calculated_hit(mastered, target, rng: fn _ -> 100 end)

    assert abs(mastered_swing.primary.damage - unmastered_swing.primary.damage * 2) <= 1
    assert mastered_swing.secondary.damage > unmastered_swing.secondary.damage * 2

    double =
      start_assassin(
        equipped: [right: @knife],
        skills: %{@tf_double => 10},
        dex: 1
      )

    defender = MobState.to_combatant(mob_state(target))
    attacker = PlayerState.to_combatant(player_state(double))
    flee = attacker.combat_stats.hit - 5
    defender = %{defender | combat_stats: %{defender.combat_stats | flee: flee, perfect_dodge: 0}}

    :rand.seed(:exsss, {1, 1, 1})

    failed =
      HandedAttack.calculate(player_state(double), attacker, defender, rng: fn _ -> 100 end)

    :rand.seed(:exsss, {1, 1, 1})

    succeeded =
      HandedAttack.calculate(player_state(double), attacker, defender, rng: fn _ -> 1 end)

    assert {:ok, %{display_divisions: 1, outcome: :miss}} = failed
    assert {:ok, %{display_divisions: 2, outcome: outcome}} = succeeded
    assert outcome in [:hit, :critical]
    assert attacker.combat_stats.hit == player_state(double).stats.combat_stats.hit

    katar = start_assassin(equipped: [both: @jur], skills: %{@tf_double => 10}, luk: 30)
    plant = start_target(unique_id(), race: :plant)
    ordinary = start_target(unique_id(), race: :formless)

    assert player_state(katar).stats.combat_stats.critical > 0
    assert calculated_hit(katar, plant).secondary == nil
    assert calculated_hit(katar, ordinary).secondary.damage > 0

    skill_user =
      start_assassin(
        equipped: [right: @knife, left: @knife_slotted],
        skills: %{@tf_poison => 10}
      )

    skill_target = start_target(unique_id(), race: :formless)
    hp_before = mob_state(skill_target).hp
    cast_skill(skill_user, @tf_poison, 10, skill_target.unit_id)

    packet =
      await_packet(
        SkillDamage,
        &(&1.skill_id == @tf_poison and &1.target_id == skill_target.unit_id)
      )

    assert eventually(fn -> mob_state(skill_target).hp < hp_before end)
    assert hp_before - mob_state(skill_target).hp == packet.damage
  end

  test "Lex, Kyrie, and Safety Wall consume one aggregate dual-hand swing on a real mob" do
    Enum.each([:lex, :kyrie, :safety_wall], fn absorber ->
      player =
        start_assassin(equipped: [right: @knife, left: @knife_slotted], skills: mastery_skills())

      mob = start_target(unique_id(), race: :formless)
      arm_mob_absorber(mob, absorber)
      {packet, hp_loss} = one_swing(player, mob)
      assert hp_loss == packet.damage + packet.damage2

      case absorber do
        :lex ->
          refute StatusStorage.has_status?(:mob, mob.unit_id, :sc_aeterna)

        :kyrie ->
          assert hp_loss == 0

          assert %{state: %{hits_remaining: 4}} =
                   StatusStorage.get_status(:mob, mob.unit_id, :sc_kyrie)

        :safety_wall ->
          assert hp_loss == 0
          assert %Group{state: %{hits_remaining: 5}} = SkillUnitStorage.get(mob.unit_id)
      end
    end)
  end

  test "valid and stale Devotion settle one real calculated dual-hand swing" do
    attacker =
      start_assassin(equipped: [right: @knife, left: @knife_slotted], skills: mastery_skills())

    devotee = start_player(class: 0, position: {151, 150}, hp: 20_000, max_hp: 20_000)
    crusader = start_player(class: @crusader, position: {152, 150}, hp: 20_000, max_hp: 20_000)
    link_devotion(crusader, devotee)

    swing = calculated_player_target_hit(attacker, devotee)
    devotee_hp = current_hp(devotee)
    crusader_hp = current_hp(crusader)

    # Entered at apply_weapon_swing because AutoAttack's player-target route is
    # PvP-gated (auto_attack.ex:729); lift to the AutoAttack entry when PvP lands.
    {_settled, :ok} = settle_player_swing(attacker, devotee, swing)

    assert eventually(fn -> current_hp(crusader) == crusader_hp - swing.raw_total end)
    assert current_hp(devotee) == devotee_hp

    stale_devotee = start_player(class: 0, position: {151, 152}, hp: 20_000, max_hp: 20_000)

    stale_crusader =
      start_player(class: @crusader, position: {152, 152}, hp: 20_000, max_hp: 20_000)

    link_devotion(stale_crusader, stale_devotee)
    SpatialIndex.update_unit_position(:player, stale_crusader.character.id, 250, 250, @map)

    stale_swing = calculated_player_target_hit(attacker, stale_devotee)
    stale_hp = current_hp(stale_devotee)
    {_settled, :ok} = settle_player_swing(attacker, stale_devotee, stale_swing)

    assert eventually(fn -> current_hp(stale_devotee) == stale_hp - stale_swing.raw_total end)
    refute StatusStorage.has_status?(:player, stale_devotee.character.id, :sc_devotion)
    assert DevotedBy.count(stale_crusader.character.id) == 0
  end

  test "Energy Coat consumes SP once for one real calculated dual-hand swing" do
    attacker =
      start_assassin(equipped: [right: @knife, left: @knife_slotted], skills: mastery_skills())

    target =
      start_player(
        class: 0,
        position: {151, 150},
        hp: 20_000,
        max_hp: 20_000,
        sp: 100,
        max_sp: 100
      )

    assert :ok = StatusInterpreter.apply_status(:player, target.character.id, :sc_energycoat)

    swing = calculated_player_target_hit(attacker, target)
    hp_before = current_hp(target)
    sp_before = current_sp(target)

    # Entered at apply_weapon_swing because AutoAttack's player-target route is
    # PvP-gated (auto_attack.ex:729); lift to the AutoAttack entry when PvP lands.
    {settled, :ok} = settle_player_swing(attacker, target, swing)

    assert eventually(fn -> current_hp(target) < hp_before and current_sp(target) < sp_before end)
    assert hp_before - current_hp(target) == settled.primary.damage + settled.secondary.damage
    assert sp_before - current_sp(target) == 3
  end

  test "break, drain, Enchant Poison, Poison React, and passive division hooks stay swing-scoped" do
    Application.put_env(:zone_server, :natural_break_rate, 10_000)

    breaker =
      start_assassin(equipped: [right: @knife, left: @knife_slotted], skills: mastery_skills())

    break_target = start_target(unique_id(), race: :formless)
    send_attack(breaker, break_target.unit_id)
    _packet = await_damage(breaker, break_target)

    assert eventually(fn ->
             breaker
             |> player_state()
             |> Map.fetch!(:inventory)
             |> Map.values()
             |> Enum.count(&(&1.attribute == 1)) == 1
           end)

    Application.put_env(:zone_server, :natural_break_rate, 0)

    drainer =
      start_assassin(
        equipped: [right: @knife, left: @knife_slotted, head: {@vanargandr_helm, 9}],
        skills: mastery_skills(),
        hp: 1
      )

    drain_target = start_target(unique_id(), race: :formless, hp: 1_000_000, max_hp: 1_000_000)
    assert drain_once(drainer, drain_target)

    enchanted =
      start_assassin(
        equipped: [right: @knife, left: @knife_slotted],
        skills: Map.merge(mastery_skills(), %{@as_enchantpoison => 10})
      )

    assert :ok =
             StatusInterpreter.apply_status(:player, enchanted.character.id, :sc_encpoison,
               val1: 10,
               duration: 60_000
             )

    poison_target = start_target(unique_id(), race: :formless, hp: 1_000_000, max_hp: 1_000_000)
    assert attack_until_status(enchanted, poison_target, :sc_poison, 200)

    reactor =
      start_assassin(
        equipped: [right: @knife, left: @knife_slotted],
        skills: Map.merge(mastery_skills(), %{@as_poisonreact => 10})
      )

    assert :ok =
             StatusInterpreter.apply_status(:player, reactor.character.id, :sc_poisonreact,
               val1: 10,
               duration: 60_000
             )

    :ok =
      StatusStorage.update_status(:player, reactor.character.id, :sc_poisonreact, fn status ->
        put_in(status.state.mode, :boost)
      end)

    react_target = start_target(unique_id(), race: :formless)
    {_packet, _hp_loss} = landed_swing(reactor, react_target)
    refute StatusStorage.has_status?(:player, reactor.character.id, :sc_poisonreact)

    passive_user =
      start_assassin(
        equipped: [right: @knife, left: @knife_slotted],
        skills: mastery_skills()
      )

    passive_target = start_target(unique_id(), race: :formless)

    on_exit(fn ->
      :erlang.trace_pattern({AutoAttack, :dispatch_normal_hit_passives, 4}, false, [:local])
    end)

    assert :erlang.trace_pattern({AutoAttack, :dispatch_normal_hit_passives, 4}, true, [:local]) >
             0

    test_pid = self()
    tracer_pid = spawn_link(fn -> forward_traces(test_pid) end)
    assert :erlang.trace(self(), true, [:call, {:tracer, tracer_pid}]) == 1
    :rand.seed(:exsss, {1, 1, 1})
    {passive_packet, _hp_loss} = one_swing(passive_user, passive_target)
    assert passive_packet.damage2 > 0

    assert_receive {:trace, trace_pid, :call,
                    {AutoAttack, :dispatch_normal_hit_passives, [_state, :mob, _id, _target]}}

    assert trace_pid == self()

    refute_receive {:trace, ^trace_pid, :call, {AutoAttack, :dispatch_normal_hit_passives, _args}}

    assert :erlang.trace(self(), false, [:call]) == 1

    assert :erlang.trace_pattern({AutoAttack, :dispatch_normal_hit_passives, 4}, false, [:local]) >
             0

    double = start_assassin(equipped: [right: @knife], skills: %{@tf_double => 10})
    double_target = start_target(unique_id(), race: :formless)
    :rand.seed(:exsss, {1, 1, 1})
    {packet, _hp_loss} = landed_swing(double, double_target, true)
    assert packet.div == 2
    assert packet.damage2 == 0
  end

  defp mastery_skills, do: %{@as_right => 5, @as_left => 5}

  defp forward_traces(test_pid) do
    receive do
      {:trace, _pid, :call, _mfa} = trace ->
        send(test_pid, trace)
        forward_traces(test_pid)
    end
  end

  defp start_assassin(opts) do
    equipment = Keyword.get(opts, :equipped, [])
    items = Keyword.get(opts, :items, [])
    character = insert_character(@assassin, opts)

    Enum.each(items, &seed_item(character.id, &1, 0, 0))

    Enum.each(equipment, fn
      {:right, id} -> seed_item(character.id, id, @right_hand, 0)
      {:left, id} -> seed_item(character.id, id, @left_hand, 0)
      {:both, id} -> seed_item(character.id, id, @both_hands, 0)
      {:head, {id, refine}} -> seed_item(character.id, id, @head_top, refine)
    end)

    start_session(character, {150, 150})
  end

  defp start_player(opts) do
    position = Keyword.fetch!(opts, :position)
    character = insert_character(Keyword.fetch!(opts, :class), opts)
    start_session(character, position)
  end

  defp start_session(character, position) do
    session = start_player_session(character: character, map_name: @map, position: position)
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp start_target(unit_id, opts) do
    mob =
      start_mob_session(
        Keyword.merge(
          [unit_id: unit_id, map_name: @map, position: {151, 150}, hp: 100_000, max_hp: 100_000],
          opts
        )
      )

    state = mob_state(mob)
    stats = %{state.mob_data.stats | luk: 0, agi: 1}
    updated = %{state | mob_data: %{state.mob_data | stats: stats}}
    :ok = UnitRegistry.update_unit_state(:mob, mob.unit_id, updated)
    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)
    mob
  end

  defp equip!(player, item_id, position) do
    index = inventory_index(player, item_id)

    simulate_incoming_message(player.pid, %EquipItem{
      index: PlayerState.client_index(index),
      position: position
    })

    assert eventually(fn -> player_state(player).inventory[index].equip == position end)
  end

  defp unequip_all!(player) do
    player_state(player).inventory
    |> Enum.filter(fn {_index, item} -> item.equip != 0 end)
    |> Enum.each(fn {index, _item} ->
      simulate_incoming_message(player.pid, %Aesir.Net.UnequipItem{
        index: PlayerState.client_index(index)
      })
    end)

    assert eventually(fn ->
             Enum.all?(player_state(player).inventory, fn {_i, item} -> item.equip == 0 end)
           end)
  end

  defp landed_swing(player, mob, require_double? \\ false) do
    Enum.reduce_while(1..40, nil, fn _, _ ->
      hp_before = mob_state(mob).hp
      flush_packets()

      assert :ok =
               Combat.execute_attack(
                 player_state(player).stats,
                 player_state(player),
                 mob.unit_id
               )

      packets = collect_packets_of_type(DamageDealt, 100)

      packet =
        Enum.find(packets, fn packet ->
          packet.src_id == player.character.id and packet.target_id == mob.unit_id and
            packet.damage + packet.damage2 > 0 and (not require_double? or packet.div == 2)
        end)

      if packet do
        assert eventually(fn -> mob_state(mob).hp < hp_before end)
        {:halt, {packet, hp_before - mob_state(mob).hp}}
      else
        {:cont, nil}
      end
    end) || flunk("no qualifying landed swing")
  end

  defp one_swing(player, mob) do
    hp_before = mob_state(mob).hp
    flush_packets()

    assert :ok =
             Combat.execute_attack(player_state(player).stats, player_state(player), mob.unit_id)

    packet =
      await_packet(DamageDealt, fn packet ->
        packet.src_id == player.character.id and packet.target_id == mob.unit_id and
          packet.type != 10
      end)

    assert eventually(fn -> mob_state(mob).hp <= hp_before end)
    {packet, hp_before - mob_state(mob).hp}
  end

  defp send_attack(player, target_id) do
    simulate_incoming_message(player.pid, %ActionRequest{target_id: target_id, action: 0})
  end

  defp await_damage(player, mob) do
    await_packet(DamageDealt, fn packet ->
      packet.src_id == player.character.id and packet.target_id == mob.unit_id and
        packet.damage > 0
    end)
  end

  defp await_packet(module, predicate) do
    deadline = System.monotonic_time(:millisecond) + 2_000
    do_await_packet(module, predicate, deadline)
  end

  defp do_await_packet(module, predicate, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:packet_sent, %{__struct__: ^module} = packet, _channel} ->
        if predicate.(packet), do: packet, else: do_await_packet(module, predicate, deadline)
    after
      remaining -> flunk("timed out waiting for #{inspect(module)}")
    end
  end

  defp calculated_hit(player, mob, opts \\ []) do
    player_state = player_state(player)
    attacker = PlayerState.to_combatant(player_state)
    defender = MobState.to_combatant(mob_state(mob))

    Enum.reduce_while(1..50, nil, fn _, _ ->
      {:ok, swing} = HandedAttack.calculate(player_state, attacker, defender, opts)
      if swing.outcome in [:hit, :critical], do: {:halt, swing}, else: {:cont, nil}
    end) || flunk("handed calculation never hit")
  end

  defp calculated_player_target_hit(attacker, target) do
    attacker_state = player_state(attacker)
    attacker_combatant = PlayerState.to_combatant(attacker_state)
    defender = PlayerState.to_combatant(player_state(target))

    Enum.reduce_while(1..50, nil, fn _, _ ->
      {:ok, swing} =
        HandedAttack.calculate(attacker_state, attacker_combatant, defender, rng: fn _ -> 100 end)

      if swing.outcome in [:hit, :critical], do: {:halt, swing}, else: {:cont, nil}
    end) || flunk("handed player-target calculation never hit")
  end

  defp settle_player_swing(attacker, target, swing) do
    DamageApplication.apply_weapon_swing(
      :player,
      target.pid,
      target.character.id,
      swing,
      %{
        dmg_type: :physical,
        is_short: true,
        element: swing.primary_element,
        skill_id: nil,
        skill_level: nil,
        from_caster?: true,
        basic_attack?: true
      },
      {:player, attacker.character.id}
    )
  end

  defp arm_mob_absorber(mob, :lex) do
    :rand.seed(:exsss, {1, 1, 1})
    assert :ok = StatusInterpreter.apply_status(:mob, mob.unit_id, :sc_aeterna)
  end

  defp arm_mob_absorber(mob, :kyrie) do
    assert :ok =
             StatusInterpreter.apply_status(:mob, mob.unit_id, :sc_kyrie, val2: 100_000, val3: 5)
  end

  defp arm_mob_absorber(mob, :safety_wall) do
    manager =
      start_supervised!(
        {SkillUnitManager, name: nil, schedule_tick: fn _pid, _interval -> :ok end}
      )

    Process.put({SkillUnitManager, :server}, manager)
    on_exit(fn -> Process.delete({SkillUnitManager, :server}) end)

    SkillUnitStorage.insert(%Group{
      group_id: mob.unit_id,
      skill_id: 12,
      skill_name: :mg_safetywall,
      level: 5,
      caster_id: 2_000,
      caster_type: :player,
      map_name: @map,
      center: {151, 150},
      cells: [{151, 150}],
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      state: %{hits_remaining: 6, shield_hp: 100_000}
    })

    assert :ok =
             StatusInterpreter.apply_status(:mob, mob.unit_id, :sc_safetywall, val2: mob.unit_id)
  end

  defp link_devotion(crusader, devotee) do
    link_id = make_ref()

    assert :ok =
             StatusInterpreter.apply_status(:player, devotee.character.id, :sc_devotion,
               caster_id: crusader.character.id,
               duration: 60_000,
               state: %{peer: {:player, crusader.character.id}, link_id: link_id, range: 7}
             )

    assert :ok = DevotedBy.link(crusader.character.id, devotee.character.id, link_id)
  end

  # HP drain rolls exactly once per landed swing, over the aggregate settled
  # damage (packet.damage + packet.damage2), never once per hand — proving the
  # dual-dagger swing settles a single drain. `Combat.execute_attack` runs in
  # the test process (same as combat_test.exs), so a Mimic spy on the real
  # HpDrain seam is deterministic and free of the natural-regen HP noise that a
  # sleep+HP-delta measurement would suffer. The proc chance / heal amount
  # formula itself is covered by HpDrain's own unit tests.
  defp drain_once(player, mob) do
    Mimic.copy(HpDrain)
    test_pid = self()

    Mimic.stub(HpDrain, :roll, fn _attacker, damage ->
      send(test_pid, {:drain_roll, damage})
      0
    end)

    {packet, _loss} = landed_swing(player, mob)

    assert_received {:drain_roll, drain_damage}
    refute_received {:drain_roll, _}
    assert drain_damage == packet.damage + packet.damage2
    true
  end

  defp attack_until_status(player, mob, status, attempts) do
    Enum.reduce_while(1..attempts, false, fn _, _ ->
      {_packet, _loss} = landed_swing(player, mob)

      if StatusStorage.has_status?(:mob, mob.unit_id, status) do
        {:halt, true}
      else
        {:cont, false}
      end
    end)
  end

  defp cast_skill(player, skill_id, level, target_id) do
    simulate_incoming_message(player.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id
    })
  end

  defp inventory_index(player, item_id) do
    Enum.find_value(player_state(player).inventory, fn {index, item} ->
      if item.nameid == item_id, do: index
    end)
  end

  defp player_state(player), do: get_player_state(player.pid)
  defp mob_state(mob), do: get_mob_state(mob.pid)
  defp current_hp(player), do: player_state(player).stats.current_state.hp
  defp current_sp(player), do: player_state(player).stats.current_state.sp
  defp unique_id, do: System.unique_integer([:positive])

  defp seed_item(character_id, item_id, equip, refine) do
    {:ok, item} =
      InventoryPersistence.insert_item(character_id, %{
        nameid: item_id,
        amount: 1,
        identify: 1,
        equip: equip,
        refine: refine
      })

    item
  end

  defp insert_character(class, opts) do
    uniq = unique_id()
    skills = Keyword.get(opts, :skills, %{})

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "assassin#{uniq}",
        userid: "assassin#{uniq}",
        user_pass: "password",
        email: "assassin#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs = %{
      account_id: account.id,
      char_num: 0,
      name: "Assassin#{uniq}",
      class: class,
      base_level: 99,
      job_level: 50,
      str: Keyword.get(opts, :str, 80),
      agi: Keyword.get(opts, :agi, 80),
      vit: 20,
      int: 20,
      dex: Keyword.get(opts, :dex, 99),
      luk: Keyword.get(opts, :luk, 1),
      hp: Keyword.get(opts, :hp, 20_000),
      max_hp: Keyword.get(opts, :max_hp, 20_000),
      sp: Keyword.get(opts, :sp, 1_000),
      max_sp: Keyword.get(opts, :max_sp, 1_000),
      skill_point: 0,
      learned_skills: Map.new(skills, fn {id, level} -> {Integer.to_string(id), level} end),
      last_map: @map,
      last_x: 150,
      last_y: 150,
      save_map: @map,
      save_x: 150,
      save_y: 150
    }

    {:ok, character} = %Character{} |> Character.changeset(attrs) |> Repo.insert()
    character
  end
end
