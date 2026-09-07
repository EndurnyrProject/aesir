defmodule Aesir.ZoneServer.Integration.GvgRulesIntegrationTest do
  @moduledoc """
  Cross-component siege-ground settlement and session restrictions, with ordinary
  map controls. Expectations compare real packet delivery, never mocked rates.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Ecto.Query

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MapMove
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.ParamChange
  alias Aesir.Net.Respawn
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillDamage
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: FieldManager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: FieldStorage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DevotedBy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "aldeg_cas01"

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok = MapFlags.reload()
    start_per_test_map(@map)
    :ok
  end

  test "off-hours castle PvE retains 80% damage but only active GvG reduces flee" do
    ordinary = fighter("prontera")
    ordinary_target = target("prontera")
    castle = fighter(@map)
    castle_target = target(@map)
    base = get_player_stats(castle.pid).combat_stats
    raw = swing(ordinary, ordinary_target)
    off_hours = swing(castle, castle_target)
    assert raw.damage > 1
    assert off_hours.damage == div(raw.damage * 80, 100)
    assert get_player_stats(castle.pid).combat_stats.flee == base.flee

    :ok = MapFlags.set_runtime(@map, :gvg, true)
    reduced_flee = base.flee - div(base.flee * 20, 100)
    assert_eventually(fn -> get_player_stats(castle.pid).combat_stats.flee == reduced_flee end)
    active = swing(castle, castle_target)
    assert active.damage == off_hours.damage
    assert get_player_stats(castle.pid).combat_stats.perfect_dodge == base.perfect_dodge
    :ok = PlayerSession.recalculate_stats(castle.pid, false)
    assert get_player_stats(castle.pid).combat_stats.flee == reduced_flee
    :ok = MapFlags.clear_runtime(@map, :gvg)
    assert_eventually(fn -> get_player_stats(castle.pid).combat_stats.flee == base.flee end)
  end

  test "dual hands share partial absorption once then retain 80% independently with matching packet HP" do
    ordinary = fighter("prontera", dual: true)
    ordinary_target = target("prontera")
    castle = fighter(@map, dual: true)
    castle_target = target(@map)
    raw = swing(ordinary, ordinary_target)
    assert raw.damage > 20
    assert raw.damage2 > 0

    :ok =
      StatusInterpreter.apply_status(:mob, castle_target.unit_id, :sc_kyrie, val2: 20, val3: 5)

    settled = swing(castle, castle_target)

    total = raw.damage + raw.damage2
    absorbed = total - 20
    secondary = div(absorbed * raw.damage2, total)
    assert settled.damage == div((absorbed - secondary) * 80, 100)
    assert settled.damage2 == div(secondary * 80, 100)
    refute StatusStorage.has_status?(:mob, castle_target.unit_id, :sc_kyrie)

    :ok =
      StatusInterpreter.apply_status(:mob, castle_target.unit_id, :sc_kyrie,
        val2: 100_000,
        val3: 5
      )

    blocked = swing(castle, castle_target)
    assert blocked.damage == 0
    assert blocked.damage2 == 0

    assert %{state: %{hits_remaining: 4}} =
             StatusStorage.get_status(:mob, castle_target.unit_id, :sc_kyrie)
  end

  test "fixed skill damage separates equipment return from shielded status return" do
    :ok = MapFlags.set_runtime(@map, :gvg, true)
    attacker = fighter(@map, connection_pid: tagged_connection(self(), :attacker))
    defender = fighter(@map, items: [%{nameid: 2322, equip: 16, card0: 4135}])
    assert get_player_stats(defender.pid).modifiers.equipment.short_weapon_damage_return == 30

    :ok =
      StatusInterpreter.apply_status(:player, defender.character.id, :sc_kyrie,
        val2: 200,
        val3: 5
      )

    :ok =
      StatusInterpreter.apply_status(:player, defender.character.id, :sc_reflectshield, val1: 10)

    attacker_hp = hp(attacker)
    defender_hp = hp(defender)
    expected_attacker_hp = attacker_hp - 295
    hp_param = StatusParams.hp()
    flush_packets()
    flush_recipient_packets()

    assert :ok = fixed_hit(attacker, defender)

    packet = assert_packet_sent(SkillDamage)
    assert packet.target_id == defender.character.id
    assert packet.damage == 480

    assert_receive {:recipient_packet, :attacker,
                    %ParamChange{var_id: ^hp_param, value: ^expected_attacker_hp}},
                   1000

    assert_eventually(fn -> hp(defender) == defender_hp - 480 end)
    assert_eventually(fn -> hp(attacker) == expected_attacker_hp end)
    refute StatusStorage.has_status?(:player, defender.character.id, :sc_kyrie)
  end

  test "Devotion forwards the shielded settled amount without a second shield or rate" do
    :ok = MapFlags.set_runtime(@map, :gvg, true)
    attacker = fighter(@map)
    devotee = fighter(@map)
    crusader = fighter(@map, connection_pid: tagged_connection(self(), :crusader))
    link_id = make_ref()

    :ok =
      StatusInterpreter.apply_status(:player, devotee.character.id, :sc_devotion,
        caster_id: crusader.character.id,
        duration: 60_000,
        state: %{peer: {:player, crusader.character.id}, link_id: link_id, range: 7}
      )

    :ok = DevotedBy.link(crusader.character.id, devotee.character.id, link_id)

    :ok =
      StatusInterpreter.apply_status(:player, devotee.character.id, :sc_kyrie, val2: 200, val3: 5)

    :ok =
      StatusInterpreter.apply_status(:player, crusader.character.id, :sc_kyrie,
        val2: 10_000,
        val3: 5
      )

    devotee_hp = hp(devotee)
    crusader_hp = hp(crusader)
    expected_crusader_hp = crusader_hp - 480
    hp_param = StatusParams.hp()
    flush_packets()
    flush_recipient_packets()

    assert :ok = fixed_hit(attacker, devotee)

    packet = assert_packet_sent(SkillDamage)
    assert packet.target_id == devotee.character.id
    assert packet.damage == 0

    assert_receive {:recipient_packet, :crusader,
                    %ParamChange{var_id: ^hp_param, value: ^expected_crusader_hp}},
                   1000

    assert hp(devotee) == devotee_hp
    assert_eventually(fn -> hp(crusader) == expected_crusader_hp end)

    assert %{state: %{shield_hp: 10_000, hits_remaining: 5}} =
             StatusStorage.get_status(:player, crusader.character.id, :sc_kyrie)
  end

  test "the reflected original spell settles once at its actual recipient and consumes Lex there" do
    :ok = MapFlags.set_runtime(@map, :gvg, true)
    attacker = fighter(@map)
    reflector = fighter(@map, items: [%{nameid: 2106, equip: 32, card0: 4146}])
    assert get_player_stats(reflector.pid).modifiers.equipment.magic_damage_return == 50
    stub(Resistance, :roll_success, fn chance -> chance > 0 end)
    :ok = StatusInterpreter.apply_status(:player, attacker.character.id, :sc_aeterna)
    attacker_hp = hp(attacker)
    reflector_hp = hp(reflector)
    flush_packets()

    assert {:ok, {:player, id}} =
             MagicAttack.execute_magic_damage(
               get_player_state(attacker.pid),
               reflector.character.id,
               1000,
               skill_id: 19,
               skill_level: 1
             )

    assert id == attacker.character.id

    packet = assert_packet_sent(SkillDamage)
    assert packet.target_id == attacker.character.id
    assert packet.src_id == reflector.character.id
    assert packet.damage == 1200
    assert_eventually(fn -> hp(attacker) == attacker_hp - 1200 end)
    assert hp(reflector) == reflector_hp
    refute StatusStorage.has_status?(:player, attacker.character.id, :sc_aeterna)
  end

  test "misc, ground magic and staged hits settle at delivery with matching damage packets" do
    caster = fighter(@map)
    state = get_player_state(caster.pid)

    for entry <- [:misc, :ground, :staged] do
      victim = target(@map)
      before_hp = get_mob_state(victim.pid).hp
      flush_packets()

      :ok = StatusInterpreter.apply_status(:mob, victim.unit_id, :sc_aeterna)

      case entry do
        :misc ->
          assert :ok =
                   SkillAttack.execute_misc_attack(state, {:mob, victim.unit_id},
                     skill_id: 116,
                     skill_level: 1,
                     base_damage: 1000,
                     ignore_element: true
                   )

        :ground ->
          assert :ok =
                   MagicAttack.apply_skill_unit_damage(
                     PlayerState.to_combatant(state),
                     :mob,
                     victim.unit_id,
                     89,
                     1,
                     :neutral,
                     0,
                     fixed_damage: 1000
                   )

        :staged ->
          assert {:ok, prepared} =
                   SkillAttack.prepare_staged_skill_attack(state, {:mob, victim.unit_id},
                     skill_id: 5,
                     skill_level: 1,
                     fixed_damage: 1000,
                     ignore_flee: true
                   )

          assert get_mob_state(victim.pid).hp == before_hp
          assert StatusStorage.has_status?(:mob, victim.unit_id, :sc_aeterna)
          refute_packet_sent(SkillDamage)
          assert :ok = SkillAttack.deliver_prepared_skill_hit(prepared)
      end

      packet = assert_packet_sent(SkillDamage)
      assert packet.target_id == victim.unit_id
      assert packet.damage == 1200, inspect(entry)
      assert_eventually(fn -> get_mob_state(victim.pid).hp == before_hp - packet.damage end)
      refute StatusStorage.has_status?(:mob, victim.unit_id, :sc_aeterna)
    end
  end

  for {map, flag, origin} <- [{@map, :gvg, {212, 175}}, {"prontera", :pvp, {150, 150}}] do
    @field_map map
    @versus_flag flag
    @field_origin origin
    test "paid Quagmire and Demonstration fields reach guildmates only in active versus on #{@field_map}" do
      {x, y} = @field_origin
      manager = manual_fields()

      {caster, friendly} =
        guild_pair(@field_map,
          position: {x, y},
          skills: %{"92" => 1, "229" => 1},
          items: [%{nameid: 7135, equip: 0}]
        )

      friendly_id = friendly.character.id
      before_hp = hp(friendly)
      cast_ground(caster, 92, {x + 1, y})
      quagmire = field(92)
      assert :ok = FieldManager.tick(manager, quagmire.next_tick_at)
      refute StatusStorage.has_status?(:player, friendly_id, :sc_quagmire)
      assert hp(friendly) == before_hp

      :ok = MapFlags.set_runtime(@field_map, @versus_flag, true)
      assert :ok = FieldManager.trigger(quagmire.group_id, {:player, friendly_id}, :on_touch)
      assert StatusStorage.has_status?(:player, friendly_id, :sc_quagmire)
      assert :ok = FieldManager.destroy(quagmire.group_id)
      refute StatusStorage.has_status?(:player, friendly_id, :sc_quagmire)

      assert_eventually(fn ->
        PlayerState.act_ready?(get_player_state(caster.pid), System.monotonic_time(:millisecond))
      end)

      cast_ground(caster, 229, {x + 1, y})
      demonstration = field(229)
      before_hp = hp(friendly)
      assert inventory_amount(caster, 7135) == 0
      flush_packets()
      seed_rng(manager)
      assert :ok = FieldManager.tick(manager, demonstration.next_tick_at)
      packets = collect_packets_of_type(SkillDamage)

      damage =
        packets
        |> Enum.filter(&(&1.target_id == friendly_id))
        |> Enum.uniq()
        |> Enum.map(& &1.damage)
        |> Enum.sum()

      assert damage > 0
      assert_eventually(fn -> hp(friendly) == before_hp - damage end)
      state = get_player_state(caster.pid)
      assert {:error, :invalid_target} = Combat.execute_attack(state.stats, state, friendly_id)
      :ok = FieldManager.destroy(demonstration.group_id)
      :ok = end_player_session(caster)
      :ok = end_player_session(friendly)
    end
  end

  test "paid Land Mine delivers misc damage to a guildmate through real movement contact" do
    manual_fields()

    {caster, friendly} =
      guild_pair(@map,
        position: {212, 175},
        class: 11,
        skills: %{"116" => 1},
        items: [%{nameid: 1065, equip: 0}]
      )

    :ok = MapFlags.set_runtime(@map, :gvg, true)
    cast_ground(caster, 116, {214, 175})
    mine = field(116)
    assert inventory_amount(caster, 1065) == 0
    before_hp = hp(friendly)
    flush_packets()

    simulate_incoming_message(friendly.pid, %MoveRequest{dest_x: 214, dest_y: 175})
    friendly_id = friendly.character.id

    assert_receive {:packet_sent,
                    %SkillDamage{target_id: ^friendly_id, skill_id: 116, damage: damage}, _},
                   2000

    assert damage > 0
    assert_eventually(fn -> hp(friendly) == before_hp - damage end)
    assert %{state: %{trap: %{phase: :used}}} = FieldStorage.get(mine.group_id)
    :ok = FieldManager.destroy(mine.group_id)
    :ok = end_player_session(caster)
    :ok = end_player_session(friendly)
  end

  test "ordinary and castle hostility retain real basic, Bash and Fire Bolt packet delivery" do
    for map <- ["prontera", @map] do
      {x, y} = if map == @map, do: {212, 175}, else: {150, 150}
      attacker = fighter(map, position: {x, y}, skills: %{"5" => 1, "19" => 1})
      defender = fighter(map, position: {x + 1, y}, agi: 0)
      before_hp = hp(defender)
      state = get_player_state(attacker.pid)

      assert {:error, :invalid_target} =
               Combat.execute_attack(state.stats, state, defender.character.id)

      assert hp(defender) == before_hp
      :ok = MapFlags.set_runtime(map, if(map == @map, do: :gvg, else: :pvp), true)

      flush_packets()
      seed_rng(attacker.pid)

      simulate_incoming_message(attacker.pid, %ActionRequest{
        target_id: defender.character.id,
        action: 0
      })

      id = defender.character.id
      assert_receive {:packet_sent, %DamageDealt{target_id: ^id} = packet, _}, 1000
      assert packet.damage > 0
      assert_eventually(fn -> hp(defender) == before_hp - packet.damage - packet.damage2 end)

      for skill_id <- [5, 19] do
        assert_eventually(fn -> get_player_state(attacker.pid).action_state == :idle end)

        assert_eventually(fn ->
          PlayerState.act_ready?(
            get_player_state(attacker.pid),
            System.monotonic_time(:millisecond)
          )
        end)

        before_hp = hp(defender)
        before_sp = get_player_state(attacker.pid).stats.current_state.sp
        flush_packets()
        seed_rng(attacker.pid)

        simulate_incoming_message(attacker.pid, %SkillCast{
          skill_id: skill_id,
          level: 1,
          target_id: id
        })

        assert_receive {:packet_sent,
                        %SkillDamage{target_id: ^id, skill_id: ^skill_id, damage: damage}, _},
                       3000

        assert damage > 0
        assert_eventually(fn -> hp(defender) == before_hp - damage end)
        assert get_player_state(attacker.pid).stats.current_state.sp < before_sp
      end
    end
  end

  test "a combat death still respawns on the same castle without EXP penalty" do
    :ok = CastleDb.reload()
    {:ok, castle} = CastleDb.by_map(@map)
    :ok = MapFlags.set_runtime(@map, :gvg, true)
    attacker = fighter(@map)
    victim = fighter(@map, base_exp: 10_000, job_exp: 10_000)
    initial = get_player_state(victim.pid)
    before_hp = hp(victim)
    flush_packets()

    assert :ok =
             SkillAttack.execute_skill_attack(get_player_state(attacker.pid), victim.character.id,
               skill_id: 5,
               skill_level: 1,
               fixed_damage: div(before_hp * 100 + 59, 60)
             )

    packet = assert_packet_sent(SkillDamage)
    assert packet.damage == before_hp
    assert_eventually(fn -> get_player_state(victim.pid).action_state == :dead end)
    assert hp(victim) == 0
    dead = get_player_state(victim.pid)
    assert dead.stats.progression.base_exp == initial.stats.progression.base_exp
    assert dead.stats.progression.job_exp == initial.stats.progression.job_exp
    simulate_incoming_message(victim.pid, %Respawn{type: 0})
    assert_receive {:packet_sent, %MapMove{map_name: @map, x: x, y: y}, _}, 1000
    assert {x, y} == castle.respawn
    assert get_player_state(victim.pid).map_name == @map
    assert hp(victim) > 0
  end

  test "Portal respects ground admission across mode-specific cast timing" do
    player = fighter("prontera", skills: %{"27" => 1}, items: [%{nameid: 717, equip: 0}])
    before_sp = get_player_state(player.pid).stats.current_state.sp
    cast_ground(player, 27, {151, 150})

    if GameMode.mode() == :renewal do
      assert get_player_state(player.pid).action_state == :casting
      :ok = :sys.suspend(player.pid)

      try do
        :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)
      after
        :ok = :sys.resume(player.pid)
      end

      assert_receive {:packet_sent, %SkillCastFailed{skill_id: 27}, _}, 2000
      assert FieldStorage.all() == []
      assert inventory_amount(player, 717) == 1
      assert get_player_state(player.pid).stats.current_state.sp == before_sp
    else
      assert field(27).caster_id == player.character.id
      assert inventory_amount(player, 717) == 0
      assert get_player_state(player.pid).stats.current_state.sp == before_sp - 35
      :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)
      newcomer = fighter("prontera", skills: %{"27" => 1}, items: [%{nameid: 717, equip: 0}])
      cast_ground(newcomer, 27, {152, 150})
      assert_receive {:packet_sent, %SkillCastFailed{skill_id: 27}, _}, 1000
      assert inventory_amount(newcomer, 717) == 1
    end
  end

  test "offensive knockback is blocked off-hours while pull and self relocation still commit" do
    victim = fighter(@map, position: {212, 175}, skills: %{"264" => 1})
    assert {:ok, {212, 175}} = Knockback.knockback(:player, victim.character.id, 211, 175, 2)
    assert {get_player_state(victim.pid).x, get_player_state(victim.pid).y} == {212, 175}
    assert {:ok, {213, 175}} = Knockback.pull_to(:player, victim.character.id, 213, 175)
    assert_eventually(fn -> get_player_state(victim.pid).x == 213 end)

    :ok =
      StatusInterpreter.apply_status(:player, victim.character.id, :sc_explosionspirits, val1: 5)

    cast_ground(victim, 264, {212, 175})
    assert_eventually(fn -> get_player_state(victim.pid).x == 212 end)
    ordinary = fighter("prontera")
    assert {:ok, {152, 150}} = Knockback.knockback(:player, ordinary.character.id, 149, 150, 2)
    assert_eventually(fn -> get_player_state(ordinary.pid).x == 152 end)
  end

  test "Resurrection rejects castle corpses but its living undead attack still lands" do
    caster = fighter(@map, skills: %{"54" => 4}, items: [%{nameid: 717, equip: 0}])
    corpse = fighter(@map)
    :ok = PlayerSession.apply_damage(corpse.pid, hp(corpse), nil)
    assert_eventually(fn -> hp(corpse) == 0 end)
    before_sp = get_player_state(caster.pid).stats.current_state.sp

    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: 54,
      level: 4,
      target_id: corpse.character.id
    })

    assert_receive {:packet_sent, %SkillCastFailed{skill_id: 54}, _}, 1000
    assert hp(corpse) == 0
    assert inventory_amount(caster, 717) == 1
    assert get_player_state(caster.pid).stats.current_state.sp == before_sp

    undead =
      start_mob_session(
        map_name: @map,
        position: {151, 150},
        race: :undead,
        modes: [:boss],
        hp: 100_000,
        max_hp: 100_000
      )

    flush_packets()

    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: 54,
      level: 4,
      target_id: undead.unit_id
    })

    id = undead.unit_id

    assert_receive {:packet_sent, %SkillDamage{target_id: ^id, skill_id: 54, damage: damage}, _},
                   1000

    assert damage > 0
    assert_eventually(fn -> get_mob_state(undead.pid).hp == 100_000 - damage end)
    assert inventory_amount(caster, 717) == 0
  end

  test "Redemptio rejects revival before its caster self-cost on off-hours castle ground" do
    caster = fighter(@map, class: 8, skills: %{"1014" => 1})
    corpse = fighter(@map)
    {:ok, party} = PartyManager.create("Rescue#{caster.character.id}", caster.character)
    {:ok, _party} = PartyManager.add_member(party.party_id, corpse.character)
    :ok = end_player_session(caster)
    :ok = end_player_session(corpse)
    caster = start_player_session(character: Repo.get!(Character, caster.character.id))
    corpse = start_player_session(character: Repo.get!(Character, corpse.character.id))
    :ok = PlayerSession.apply_damage(corpse.pid, hp(corpse), nil)
    assert_eventually(fn -> hp(corpse) == 0 end)
    before = get_player_state(caster.pid).stats.current_state

    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: 1014,
      level: 1,
      target_id: caster.character.id
    })

    assert_receive {:packet_sent, %SkillCastFailed{skill_id: 1014}, _}, 1000
    assert get_player_state(caster.pid).stats.current_state == before
    assert hp(corpse) == 0
  end

  test "guild area actives require ground while recall filters nowarp sources even off-hours" do
    {master, member} = guild_pair("prontera", [])
    guild_id = get_player_state(master.pid).guild_id
    skills = [10_010, 10_011, 10_012, 10_013, 10_019]
    learned = Map.new(skills, &{Integer.to_string(&1), 1})

    {1, nil} =
      from(g in GuildModel, where: g.id == ^guild_id)
      |> Repo.update_all(set: [learned_skills: learned])

    :ok = ClusterTestHelper.clear_all()
    {:ok, _guild} = GuildManager.ensure_started(guild_id)

    for id <- skills do
      simulate_incoming_message(master.pid, %SkillCast{
        skill_id: id,
        level: 1,
        target_id: master.character.id
      })

      assert_receive {:packet_sent, %SkillCastFailed{skill_id: ^id}, _}, 1000
    end

    assert {:error, :not_gvg_ground} =
             SkillInterpreter.item_cast(get_player_state(master.pid), 10_015, 1, :self)

    :ok = PlayerSession.warp(master.pid, @map, 212, 175)
    simulate_incoming_message(master.pid, %MapLoaded{})
    assert_eventually(fn -> get_player_state(master.pid).pending_map_load == nil end)
    :ok = PlayerSession.warp(member.pid, @map, 213, 175)
    simulate_incoming_message(member.pid, %MapLoaded{})
    assert_eventually(fn -> get_player_state(member.pid).pending_map_load == nil end)

    for {id, status} <- [
          {10_010, :sc_battleorder},
          {10_011, :sc_regeneration},
          {10_019, :sc_emergency_move}
        ] do
      simulate_incoming_message(member.pid, %SkillCast{
        skill_id: id,
        level: 1,
        target_id: member.character.id
      })

      assert_receive {:packet_sent, %SkillCastFailed{skill_id: ^id}, _}, 1000

      simulate_incoming_message(master.pid, %SkillCast{
        skill_id: id,
        level: 1,
        target_id: master.character.id
      })

      assert_eventually(fn -> StatusStorage.has_status?(:player, member.character.id, status) end)
    end

    max_hp = get_player_state(member.pid).stats.derived_stats.max_hp
    :ok = PlayerSession.apply_damage(member.pid, hp(member) - div(max_hp, 2), nil)
    wounded_hp = hp(member)

    simulate_incoming_message(master.pid, %SkillCast{
      skill_id: 10_012,
      level: 1,
      target_id: master.character.id
    })

    refute_receive {:packet_sent, %SkillCastFailed{skill_id: 10_012}, _}, 1500
    assert_eventually(fn -> hp(member) > wounded_hp end)
    :ok = PlayerSession.warp(member.pid, "prontera", 150, 150)
    simulate_incoming_message(member.pid, %MapLoaded{})
    :ok = MapFlags.set_runtime("prontera", :nowarp, true)
    flush_packets()

    simulate_incoming_message(master.pid, %SkillCast{
      skill_id: 10_013,
      level: 1,
      target_id: master.character.id
    })

    assert_eventually(fn -> get_player_state(master.pid).action_state == :idle end, 6000)
    assert get_player_state(member.pid).map_name == "prontera"
    refute_packet_sent(MapMove)
    :ok = MapFlags.set_runtime("prontera", :gvg, true)

    assert {:ok, _state} =
             SkillInterpreter.item_cast(get_player_state(master.pid), 10_015, 1, :self)

    assert_eventually(fn -> get_player_state(member.pid).map_name == @map end)
    assert_receive {:packet_sent, %MapMove{map_name: @map}, _}, 1000
  end

  test "ordinary casts are denied off-hours before costs but item Teleport retains its separate ingress" do
    snatcher = fighter("prontera", skills: %{"219" => 1})
    snatch_target = target("prontera")
    snatch_target_hp = get_mob_state(snatch_target.pid).hp
    flush_packets()
    seed_rng(snatcher.pid)

    simulate_incoming_message(snatcher.pid, %SkillCast{
      skill_id: 219,
      level: 1,
      target_id: snatch_target.unit_id
    })

    target_id = snatch_target.unit_id

    assert_receive {:packet_sent,
                    %SkillDamage{target_id: ^target_id, skill_id: 219, damage: snatch_damage}, _},
                   1000

    assert snatch_damage > 0

    assert_eventually(fn ->
      get_mob_state(snatch_target.pid).hp == snatch_target_hp - snatch_damage
    end)

    for id <- [26, 27, 87, 150, 219] do
      player = fighter(@map, skills: %{Integer.to_string(id) => 1})
      snatch_target = if id == 219, do: target(@map)
      target_id = if snatch_target, do: snatch_target.unit_id, else: player.character.id
      target_hp = if snatch_target, do: get_mob_state(snatch_target.pid).hp
      before = get_player_state(player.pid)
      flush_packets()

      message =
        if id in [27, 87],
          do: %GroundSkillCast{skill_id: id, level: 1, x: 151, y: 150},
          else: %SkillCast{skill_id: id, level: 1, target_id: target_id}

      simulate_incoming_message(player.pid, message)
      assert_receive {:packet_sent, %SkillCastFailed{skill_id: ^id}, _}, 1000
      assert get_player_state(player.pid).stats.current_state.sp == before.stats.current_state.sp
      assert get_player_state(player.pid).pending_warp == nil

      if snatch_target do
        assert get_mob_state(snatch_target.pid).hp == target_hp
      end
    end

    player = fighter(@map, items: [%{nameid: 601, equip: 0}])
    flush_packets()
    use_item(player, 601)

    assert_receive {:packet_sent, first, _}
                   when is_struct(first, ItemUseResult) or is_struct(first, MapMove),
                   1000

    assert %ItemUseResult{ok: true} = first
    assert_receive {:packet_sent, %MapMove{map_name: @map, x: x, y: y}, _}, 1000
    assert inventory_amount(player, 601) == 0
    state = get_player_state(player.pid)
    assert {state.map_name, state.x, state.y} == {@map, x, y}
    assert state.pending_warp == nil
    assert state.pending_map_load == :warp
    refute_packet_sent(MapMove)
  end

  test "Greed cast, Greed Scroll and Anodyne honor their mode and entry-specific exceptions" do
    player =
      fighter(@map,
        class: 10,
        skills: %{"1013" => 1},
        items: [%{nameid: 14_529, equip: 0}, %{nameid: 605, equip: 0}]
      )

    before_sp = get_player_state(player.pid).stats.current_state.sp

    simulate_incoming_message(player.pid, %SkillCast{
      skill_id: 1013,
      level: 1,
      target_id: player.character.id
    })

    if GameMode.mode() == :renewal do
      assert_eventually(fn ->
        get_player_state(player.pid).stats.current_state.sp == before_sp - 10
      end)
    else
      assert_receive {:packet_sent, %SkillCastFailed{skill_id: 1013}, _}, 1000
      assert get_player_state(player.pid).stats.current_state.sp == before_sp
    end

    use_item(player, 14_529)
    assert_receive {:packet_sent, %ItemUseResult{ok: false}, _}, 1000
    assert inventory_amount(player, 14_529) == 1
    use_item(player, 605)

    assert_receive {:packet_sent, %ItemUseResult{ok: false}, _}, 1000
    assert inventory_amount(player, 605) == 1

    refute StatusStorage.has_status?(:player, player.character.id, :sc_endure)
  end

  test "Endure is removed on actual castle entry and restored application is not an escape hatch" do
    player = fighter("prontera")

    :ok =
      StatusInterpreter.apply_status(:player, player.character.id, :sc_endure, duration: 30_000)

    assert StatusStorage.has_status?(:player, player.character.id, :sc_endure)
    :ok = PlayerSession.warp(player.pid, @map, 150, 150)
    assert_eventually(fn -> get_player_state(player.pid).map_name == @map end)
    refute StatusStorage.has_status?(:player, player.character.id, :sc_endure)

    assert {:error, _reason} =
             StatusInterpreter.apply_status(:player, player.character.id, :sc_endure,
               loaded: true,
               duration: 30_000
             )

    refute StatusStorage.has_status?(:player, player.character.id, :sc_endure)
  end

  defp tagged_connection(test_pid, recipient) do
    spawn_link(fn -> tagged_connection_loop(test_pid, recipient) end)
  end

  defp tagged_connection_loop(test_pid, recipient) do
    receive do
      {:send, _channel, {_wire_tag, packet}} ->
        send(test_pid, {:recipient_packet, recipient, packet})
        tagged_connection_loop(test_pid, recipient)

      _message ->
        tagged_connection_loop(test_pid, recipient)
    end
  end

  defp flush_recipient_packets do
    receive do
      {:recipient_packet, _recipient, _packet} -> flush_recipient_packets()
    after
      0 -> :ok
    end
  end

  defp seed_rng(pid) do
    :sys.replace_state(pid, fn state ->
      :rand.seed(:exsss, {17, 19, 23})
      state
    end)

    :ok
  end

  defp manual_fields do
    stop_supervised!({:integration_default, FieldManager})

    manager =
      start_supervised!({FieldManager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({FieldManager, :server}, manager)
    seed_rng(manager)
    manager
  end

  defp cast_ground(player, id, {x, y}) do
    simulate_incoming_message(player.pid, %GroundSkillCast{skill_id: id, level: 1, x: x, y: y})
  end

  defp field(id) do
    refute_receive {:packet_sent, %SkillCastFailed{skill_id: ^id}, _}, 1000
    assert_eventually(fn -> Enum.any?(FieldStorage.all(), &(&1.skill_id == id)) end)
    Enum.find(FieldStorage.all(), &(&1.skill_id == id))
  end

  defp guild_pair(map, opts) do
    caster = fighter(map, opts)
    friendly = fighter(map, position: Keyword.get(opts, :position, {150, 150}), agi: 0)
    {:ok, guild} = GuildManager.create("Field#{caster.character.id}", caster.character)
    {:ok, _guild} = GuildManager.add_member(guild.guild_id, friendly.character)
    :ok = end_player_session(caster)
    :ok = end_player_session(friendly)
    caster = start_player_session(character: Repo.get!(Character, caster.character.id))
    friendly = start_player_session(character: Repo.get!(Character, friendly.character.id))
    assert get_player_state(caster.pid).guild_id == get_player_state(friendly.pid).guild_id
    {caster, friendly}
  end

  defp use_item(player, id) do
    {index, _item} =
      Enum.find(get_player_state(player.pid).inventory, fn {_index, item} -> item.nameid == id end)

    simulate_incoming_message(player.pid, %UseItem{index: PlayerState.client_index(index)})
  end

  defp inventory_amount(player, id) do
    player.pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Map.values()
    |> Enum.filter(&(&1.nameid == id))
    |> Enum.map(& &1.amount)
    |> Enum.sum()
  end

  defp hp(player), do: get_player_state(player.pid).stats.current_state.hp

  defp fixed_hit(attacker, defender) do
    :rand.seed(:exsss, {17, 19, 23})

    SkillAttack.execute_skill_attack(get_player_state(attacker.pid), defender.character.id,
      skill_id: 5,
      skill_level: 1,
      fixed_damage: 1000
    )
  end

  defp swing(attacker, target) do
    flush_packets()
    before_hp = get_mob_state(target.pid).hp
    :rand.seed(:exsss, {17, 19, 23})
    state = get_player_state(attacker.pid)
    assert :ok = Combat.execute_attack(state.stats, state, target.unit_id)
    packet = assert_packet_sent(DamageDealt)
    assert packet.src_id == attacker.character.id
    assert packet.target_id == target.unit_id
    assert before_hp - get_mob_state(target.pid).hp == packet.damage + packet.damage2
    packet
  end

  defp target(map) do
    start_mob_session(
      map_name: map,
      position: {151, 150},
      hp: 100_000,
      max_hp: 100_000,
      agi: 0,
      vit: 0,
      luk: 0
    )
  end

  defp fighter(map, opts \\ []) do
    unique = System.unique_integer([:positive])
    {x, y} = Keyword.get(opts, :position, {150, 150})

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "g17_#{unique}",
        user_pass: "password",
        sex: "M",
        email: "g17_#{unique}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Ground#{unique}",
        class: Keyword.get(opts, :class, 12),
        base_level: 99,
        job_level: 50,
        base_exp: Keyword.get(opts, :base_exp, 0),
        job_exp: Keyword.get(opts, :job_exp, 0),
        str: 99,
        agi: Keyword.get(opts, :agi, 50),
        vit: 0,
        int: 99,
        dex: 99,
        luk: 0,
        hp: 20_000,
        max_hp: 20_000,
        sp: 10_000,
        max_sp: 10_000,
        last_map: map,
        last_x: x,
        last_y: y,
        save_map: "prontera",
        save_x: 150,
        save_y: 150,
        learned_skills: Map.merge(%{"132" => 5, "133" => 5}, Keyword.get(opts, :skills, %{}))
      })
      |> Repo.insert()

    if Keyword.get(opts, :dual, false) do
      for {id, equip} <- [{1201, 2}, {1202, 32}] do
        {:ok, _item} =
          InventoryPersistence.insert_item(character.id, %{
            nameid: id,
            amount: 1,
            identify: 1,
            equip: equip
          })
      end
    end

    for item <- Keyword.get(opts, :items, []) do
      {:ok, _item} =
        InventoryPersistence.insert_item(character.id, Map.merge(%{amount: 1, identify: 1}, item))
    end

    start_player_session(
      character: character,
      connection_pid: Keyword.get(opts, :connection_pid)
    )
  end
end
