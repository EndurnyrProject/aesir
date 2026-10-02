defmodule Aesir.ZoneServer.Integration.PaladinSkillsTest do
  @moduledoc """
  Live-session acceptance coverage for the Paladin kit in Renewal and
  pre-renewal. Network transport alone is faked; skills, combat, statuses,
  parties and ground units use their real session routes.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.CastCancel
  alias Aesir.Net.EquipItem
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DevotedBy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "prontera"
  @paladin_class 4015
  @pressure 367
  @sacrifice 368
  @gospel 369
  @shield_chain 480
  @guard 2101
  @left_hand 32

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  describe "Battle Chant" do
    test "plants a 33-cell field, locks the caster, blesses the party and afflicts enemies" do
      %{paladin: paladin, ally: ally} = party_pair()
      # VIT 0 so a rolled debuff cannot be resisted (status resistance scales with VIT).
      mob = target_mob(position: {150, 151}, vit: 0)
      :ok = StatusStorage.apply_status(:player, paladin.character.id, :sc_blessing, val1: 10)
      :ok = StatusStorage.apply_status(:player, ally.character.id, :sc_curse, val1: 1)
      PlayerSession.set_vitals(ally.pid, hp: 1)
      assert eventually(fn -> get_player_state(ally.pid).stats.current_state.hp == 1 end)

      cast(paladin, @gospel, 10)
      group_id = await_chant(paladin)

      refute StatusStorage.has_status?(:player, paladin.character.id, :sc_blessing)
      assert length(SkillUnitStorage.get(group_id).cells) == 33
      refute Interpreter.can_move?(:player, paladin.character.id)

      flush_packets()
      cast(paladin, @pressure, 1, mob.unit_id)
      assert_cast_refused(@pressure, paladin.character.id)
      assert get_mob_state(mob.pid).hp == 100_000

      ally_hp = get_player_state(ally.pid).stats.current_state.hp
      mob_hp = get_mob_state(mob.pid).hp
      manager = ProcessTree.get({SkillUnitManager, :server})
      :ok = SkillUnitManager.update_state(manager, group_id, %{rng: fn _ -> 1 end})
      :ok = SkillUnitManager.tick(manager, SkillUnitStorage.get(group_id).next_tick_at)

      assert eventually(fn -> blessed?(ally, ally_hp) end)
      assert eventually(fn -> afflicted?(mob, mob_hp) end)
    end

    test "recasting ends the chant and the field without charging SP" do
      %{paladin: paladin} = party_pair()
      cast(paladin, @gospel, 1)
      group_id = await_chant(paladin)
      sp = get_player_state(paladin.pid).stats.current_state.sp

      cast(paladin, @gospel, 1)

      assert eventually(fn ->
               not StatusStorage.has_status?(:player, paladin.character.id, :sc_gospel) and
                 SkillUnitStorage.get(group_id) == nil
             end)

      assert get_player_state(paladin.pid).stats.current_state.sp == sp
    end

    test "an unpaid upkeep tick and Silence each end the chant" do
      %{paladin: starving} = party_pair()
      cast(starving, @gospel, 1)
      group_id = await_chant(starving)
      PlayerSession.consume_sp(starving.pid, 10_000)
      assert eventually(fn -> get_player_state(starving.pid).stats.current_state.sp == 0 end)

      StatusStorage.update_status(:player, starving.character.id, :sc_gospel, fn entry ->
        %{entry | next_tick_at: System.monotonic_time(:millisecond) - 1}
      end)

      StatusTickManager.force_tick()

      assert eventually(fn ->
               not StatusStorage.has_status?(:player, starving.character.id, :sc_gospel) and
                 SkillUnitStorage.get(group_id) == nil
             end)

      %{paladin: silenced} = party_pair()
      cast(silenced, @gospel, 1)
      silenced_group = await_chant(silenced)

      :ok =
        Interpreter.apply_status(:player, silenced.character.id, :sc_silence,
          val1: 1,
          duration: 10_000,
          bypass_resistance: true
        )

      assert eventually(fn ->
               not StatusStorage.has_status?(:player, silenced.character.id, :sc_gospel) and
                 SkillUnitStorage.get(silenced_group) == nil
             end)
    end
  end

  test "Martyr's Reckoning turns five live swings into max-HP strikes that cost 9% HP each" do
    Mimic.copy(HitCalculations)
    Mimic.stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :miss end)
    paladin = paladin()
    mob = target_mob(vit: 500)
    PlayerSession.set_vitals(paladin.pid, hp: :max)
    cast(paladin, @sacrifice, 5)

    assert eventually(fn ->
             state = get_player_state(paladin.pid)

             StatusStorage.has_status?(:player, paladin.character.id, :sc_sacrifice) and
               state.stats.current_state.hp == state.stats.derived_stats.max_hp
           end)

    state = get_player_state(paladin.pid)
    max_hp = state.stats.derived_stats.max_hp
    cost = div(max_hp * 9, 100)
    hp_before = state.stats.current_state.hp
    id = paladin.character.id
    flush_packets()

    for swing <- 1..5 do
      state = get_player_state(paladin.pid)
      assert :ok = Combat.execute_attack(state.stats, state, mob.unit_id)

      assert_receive {:packet_sent, %SkillDamage{src_id: ^id, skill_id: @sacrifice, damage: dmg},
                      _},
                     1_000

      assert_in_delta dmg, cost * 140 / 100, 2

      assert eventually(fn ->
               get_player_state(paladin.pid).stats.current_state.hp == hp_before - swing * cost
             end)
    end

    refute StatusStorage.has_status?(:player, paladin.character.id, :sc_sacrifice)
    assert get_mob_state(mob.pid).hp < 100_000
  end

  @tag game_mode: :pre_renewal, integration_re: false
  test "pre-renewal Gloria Domini deals fixed damage, drains SP, ignores Devotion, refuses hiding" do
    paladin = paladin()
    mob = target_mob(vit: 500, position: {152, 150})
    flush_packets()

    cast(paladin, @pressure, 1, mob.unit_id)
    assert eventually(fn -> get_mob_state(mob.pid).hp == 100_000 - 800 end, 6_000)

    MapFlags.set_runtime(@map, :pvp, true)
    on_exit(fn -> MapFlags.clear_runtime(@map, :pvp) end)
    %{paladin: crusader, ally: devotee} = party_pair(positions: {{154, 150}, {153, 150}})
    link_devotion(crusader.character.id, devotee.character.id)
    crusader_hp = get_player_state(crusader.pid).stats.current_state.hp
    control = %{dmg_type: :weapon, is_short: true, element: :neutral}

    {redirected, prepared} =
      DamageApplication.prepare_unit_damage(
        :player,
        devotee.character.id,
        50,
        control,
        mob.unit_id
      )

    assert redirected == 0

    :ok =
      DamageApplication.apply_unit_damage(
        :player,
        devotee.pid,
        devotee.character.id,
        0,
        prepared,
        mob.unit_id
      )

    assert eventually(fn ->
             get_player_state(crusader.pid).stats.current_state.hp == crusader_hp - 50
           end)

    devotee_hp = get_player_state(devotee.pid).stats.current_state.hp
    crusader_hp = crusader_hp - 50
    devotee_stats = get_player_state(devotee.pid).stats
    devotee_sp = devotee_stats.current_state.sp
    devotee_max_sp = devotee_stats.derived_stats.max_sp

    Process.sleep(2_100)
    cast(paladin, @pressure, 1, devotee.character.id)

    assert eventually(
             fn -> get_player_state(devotee.pid).stats.current_state.hp == devotee_hp - 800 end,
             6_000
           )

    assert eventually(fn ->
             get_player_state(devotee.pid).stats.current_state.sp ==
               devotee_sp - div(devotee_max_sp * 20, 100)
           end)

    assert get_player_state(crusader.pid).stats.current_state.hp == crusader_hp

    :ok = StatusStorage.apply_status(:player, crusader.character.id, :sc_hiding, val1: 1)
    Process.sleep(2_100)
    flush_packets()
    cast(paladin, @pressure, 1, crusader.character.id)
    assert_receive {:packet_sent, %SkillCastFailed{skill_id: @pressure}, _}, 6_000
    assert get_player_state(crusader.pid).stats.current_state.hp == crusader_hp
  end

  @tag game_mode: :renewal, integration_pre_re: false
  test "renewal Gloria Domini lands one holy magic roll shown as three hits" do
    paladin = paladin()
    mob = target_mob(vit: 1)
    id = paladin.character.id
    flush_packets()

    cast(paladin, @pressure, 5, mob.unit_id)

    assert_receive {:packet_sent,
                    %SkillDamage{src_id: ^id, skill_id: @pressure, div: 3, damage: damage}, _},
                   3_000

    assert damage > 0
    refute_receive {:packet_sent, %SkillDamage{src_id: ^id, skill_id: @pressure}, _}, 300
    assert eventually(fn -> get_mob_state(mob.pid).hp < 100_000 end)
  end

  test "Rapid Smiting lands five displayed shield hits and is refused without a shield" do
    force_hits()
    armed = paladin(items: [%{nameid: @guard, amount: 1, identify: 1}])
    equip!(armed, @guard, @left_hand)
    mob = target_mob(vit: 1)
    id = armed.character.id
    flush_packets()

    cast(armed, @shield_chain, 1, mob.unit_id)

    assert_receive {:packet_sent,
                    %SkillDamage{src_id: ^id, skill_id: @shield_chain, div: 5, damage: damage},
                    _},
                   3_000

    assert damage > 0

    unarmed = paladin()
    flush_packets()
    cast(unarmed, @shield_chain, 1, mob.unit_id)
    assert_receive {:packet_sent, %SkillCastFailed{skill_id: @shield_chain}, _}, 1_000
  end

  defp await_chant(paladin) do
    assert eventually(fn ->
             StatusStorage.has_status?(:player, paladin.character.id, :sc_gospel)
           end)

    %{val2: group_id} = StatusStorage.get_status(:player, paladin.character.id, :sc_gospel)
    assert eventually(fn -> SkillUnitStorage.get(group_id) != nil end)
    group_id
  end

  defp assert_cast_refused(skill_id, character_id) do
    assert_receive {:packet_sent, packet, _}, 1_000

    case packet do
      %SkillCastFailed{skill_id: ^skill_id} -> :ok
      %CastCancel{gid: ^character_id} -> :ok
      _other -> assert_cast_refused(skill_id, character_id)
    end
  end

  defp blessed?(ally, hp_before) do
    statuses = StatusStorage.get_unit_statuses(:player, ally.character.id)
    types = MapSet.new(statuses, & &1.type)
    bless_ids = table_status_ids(Effects.bless_table())

    stats = get_player_state(ally.pid).stats

    not MapSet.disjoint?(types, bless_ids) or
      (stats.current_state.hp > hp_before and
         stats.current_state.hp == stats.derived_stats.max_hp) or
      not MapSet.member?(types, :sc_curse)
  end

  defp afflicted?(mob, hp_before) do
    types = MapSet.new(StatusStorage.get_unit_statuses(:mob, mob.unit_id), & &1.type)

    not MapSet.disjoint?(types, table_status_ids(Effects.afflict_table())) or
      get_mob_state(mob.pid).hp < hp_before
  end

  defp table_status_ids(table) do
    table
    |> Enum.flat_map(fn
      {:status, id, _v, _d} -> [id]
      {:status_pair, {a, _}, {b, _}, _d} -> [a, b]
      _other -> []
    end)
    |> MapSet.new()
  end

  defp force_hits do
    Mimic.copy(HitCalculations)
    Mimic.stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
  end

  defp link_devotion(crusader_id, devotee_id) do
    link_id = make_ref()

    :ok =
      Interpreter.apply_status(:player, devotee_id, :sc_devotion,
        caster_id: crusader_id,
        duration: 60_000,
        state: %{peer: {:player, crusader_id}, link_id: link_id, range: 7}
      )

    :ok = DevotedBy.link(crusader_id, devotee_id, link_id)
  end

  defp target_mob(opts \\ []) do
    mob =
      start_mob_session(
        Keyword.merge(
          [map_name: @map, position: {151, 150}, hp: 100_000, max_hp: 100_000],
          opts
        )
      )

    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)
    mob
  end

  defp equip!(paladin, item_id, position) do
    {index, _} =
      Enum.find(get_player_state(paladin.pid).inventory, fn {_i, item} ->
        item.nameid == item_id
      end)

    simulate_incoming_message(paladin.pid, %EquipItem{
      index: PlayerState.client_index(index),
      position: position
    })

    assert eventually(fn -> get_player_state(paladin.pid).inventory[index].equip == position end)
    index
  end

  defp party_pair(opts \\ []) do
    {paladin_pos, ally_pos} = Keyword.get(opts, :positions, {{150, 150}, {151, 150}})
    paladin_char = insert_character("paladin", paladin_attrs(hp: 2_000))
    {:ok, _state} = PartyManager.create("Templars#{paladin_char.id}", paladin_char)
    party_id = Repo.get(Character, paladin_char.id).party_id

    ally_char = insert_character("ally", %{class: 0, base_level: 50, vit: 1, hp: 1_000})
    {:ok, _state} = PartyManager.add_member(party_id, ally_char)

    %{
      paladin: start_session(Repo.get(Character, paladin_char.id), paladin_pos),
      ally: start_session(Repo.get(Character, ally_char.id), ally_pos),
      party_id: party_id
    }
  end

  defp paladin(opts \\ []) do
    character = insert_character("paladin", paladin_attrs(Keyword.delete(opts, :items)))

    for item <- Keyword.get(opts, :items, []) do
      {:ok, _} = InventoryPersistence.insert_item(character.id, item)
    end

    start_session(character, {150, 150})
  end

  defp paladin_attrs(overrides) do
    Map.merge(
      %{
        class: @paladin_class,
        base_level: 99,
        job_level: 50,
        str: 80,
        agi: 40,
        vit: 40,
        int: 60,
        dex: 99,
        luk: 10,
        hp: 5_000,
        max_hp: 5_000,
        sp: 1_000,
        max_sp: 1_000,
        learned_skills: %{"367" => 5, "368" => 5, "369" => 10, "480" => 5}
      },
      Map.new(overrides)
    )
  end

  defp insert_character(prefix, overrides) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "#{prefix}#{uniq}",
        userid: "#{prefix}#{uniq}",
        user_pass: "password",
        email: "#{prefix}#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          char_num: 0,
          name: "#{prefix}#{uniq}",
          class: 0,
          base_level: 50,
          job_level: 50,
          str: 10,
          agi: 10,
          vit: 10,
          int: 10,
          dex: 10,
          luk: 10,
          hp: 5_000,
          max_hp: 5_000,
          sp: 1_000,
          max_sp: 1_000,
          skill_point: 0,
          last_map: @map,
          last_x: 150,
          last_y: 150,
          save_map: @map,
          save_x: 150,
          save_y: 150
        },
        overrides
      )

    {:ok, character} = %Character{} |> Character.changeset(attrs) |> Repo.insert()
    character
  end

  defp start_session(character, position) do
    session = start_player_session(character: character, map_name: @map, position: position)
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp cast(paladin, skill_id, level, target_id \\ nil) do
    simulate_incoming_message(paladin.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id || paladin.character.id
    })
  end
end
