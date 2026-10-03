defmodule Aesir.ZoneServer.Integration.HighPriestSkillsTest do
  @moduledoc """
  Live-session acceptance coverage for the High Priest kit in Renewal and
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
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "prontera"
  @high_priest_class 4009
  @heal 28
  @kyrie 73
  @assumptio 361
  @basilica 362
  @catalysts [715, 716, 717, 523]
  @whistle 319
  @violin 1901
  @club 1501
  @right_hand 2

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  describe "passives" do
    test "Meditatio raises max SP by 10% and strengthens Heal" do
      plain = high_priest(learned: %{"28" => 10})
      meditating = high_priest(learned: %{"28" => 10, "363" => 10})

      plain_sp = max_sp(plain)
      assert max_sp(meditating) in [div(plain_sp * 110, 100), div(plain_sp * 110, 100) + 1]

      assert heal_amount(meditating) > heal_amount(plain)
    end

    test "Mana Recharge cuts the SP a cast charges by 20%" do
      priest = high_priest(learned: %{"361" => 1, "481" => 5})
      sp = current_sp(priest)

      cast(priest, @assumptio, 1)

      # Assumptio level 1 lists 20 SP; -20% leaves 16.
      assert eventually(fn -> current_sp(priest) == sp - 16 end)
    end
  end

  describe "Assumptio" do
    @tag game_mode: :renewal, integration_pre_re: false
    test "renewal grants the ally 250 hard DEF at level 5" do
      %{priest: priest, ally: ally} = party_pair()
      def_before = get_player_state(ally.pid).stats.combat_stats.def

      cast(priest, @assumptio, 5, ally.character.id)

      assert eventually(fn ->
               get_player_state(ally.pid).stats.combat_stats.def == def_before + 250
             end)
    end

    @tag game_mode: :renewal, integration_pre_re: false
    test "renewal Heal on an Assumptio holder restores more" do
      priest = high_priest()
      patient = patient()

      plain = heal_once(priest, patient)

      clear_act_delay(priest)
      cast(priest, @assumptio, 5, patient.character.id)

      assert eventually(fn ->
               StatusStorage.has_status?(:player, patient.character.id, :sc_assumptio)
             end)

      assert heal_once(priest, patient) > plain
    end

    @tag game_mode: :pre_renewal, integration_re: false
    test "pre-renewal halves the ally's incoming damage and replaces Kyrie" do
      %{priest: priest, ally: ally} = party_pair()
      ally_id = ally.character.id

      cast(priest, @kyrie, 1, ally_id)
      assert eventually(fn -> StatusStorage.has_status?(:player, ally_id, :sc_kyrie) end)

      clear_act_delay(priest)
      cast(priest, @assumptio, 5, ally_id)

      assert eventually(fn -> StatusStorage.has_status?(:player, ally_id, :sc_assumptio) end)
      refute StatusStorage.has_status?(:player, ally_id, :sc_kyrie)

      hit = %{dmg_type: :physical, is_short: true}
      assert Interpreter.absorb_damage(:player, ally_id, 1_000, hit) == 500

      clear_act_delay(priest)
      cast(priest, @kyrie, 1, ally_id)

      assert eventually(fn ->
               StatusStorage.has_status?(:player, ally_id, :sc_kyrie) and
                 not StatusStorage.has_status?(:player, ally_id, :sc_assumptio)
             end)
    end

    test "a player cannot cast it on a monster" do
      priest = high_priest()
      mob = spawn_mob({151, 150})
      flush_packets()

      cast(priest, @assumptio, 1, mob.unit_id)

      assert_cast_refused(@assumptio, priest.character.id)
      refute StatusStorage.has_status?(:mob, mob.unit_id, :sc_assumptio)
    end
  end

  describe "renewal Basilica" do
    @describetag game_mode: :renewal, integration_pre_re: false

    test "boosts weapon damage against undead and enforces its 30 s cooldown" do
      priest = high_priest(learned: %{"362" => 5}, items: [@club])
      equip!(priest, @club, @right_hand)
      undead = spawn_mob({151, 150}, element: {:undead, 1})
      {:ok, defender} = Combat.resolve_combatant(:mob, undead.unit_id)

      base = melee_damage(priest, defender)

      cast(priest, @basilica, 5)

      assert eventually(fn ->
               StatusStorage.has_status?(:player, priest.character.id, :sc_basilica_buff)
             end)

      assert melee_damage(priest, defender) > base

      flush_packets()
      clear_act_delay(priest)
      cast(priest, @basilica, 5)

      assert_receive {:packet_sent,
                      %SkillCastFailed{
                        skill_id: @basilica,
                        reason: :SKILL_CAST_FAILURE_REASON_ON_COOLDOWN
                      }, _},
                     1_000
    end
  end

  describe "pre-renewal Basilica" do
    @describetag game_mode: :pre_renewal, integration_re: false

    test "a sanctuary shields its occupants from normal monsters but not from bosses" do
      force_hits()
      %{priest: priest, ally: ally} = party_pair(catalysts: true)
      group_id = raise_sanctuary(priest)
      walk_in(ally, {152, 150})

      for id <- @catalysts, do: refute(holds?(priest, id))
      assert get_player_state(priest.pid).act_delay_until == 0

      normal = spawn_mob({153, 150})
      boss = spawn_mob({153, 151}, modes: [:boss], level: 99)
      hp = current_hp(ally)

      assert :ok = Combat.execute_mob_attack(get_mob_state(normal.pid), ally.character.id)
      assert current_hp(ally) == hp

      assert :ok = Combat.execute_mob_attack(get_mob_state(boss.pid), ally.character.id)
      assert eventually(fn -> current_hp(ally) < hp end)

      refute Interpreter.can_move?(:player, priest.character.id)
      refute Interpreter.can_attack?(:player, ally.character.id)
      assert SkillUnitStorage.get(group_id)
    end

    test "the caster can only recast, which ends the field for free with the after-cast delay" do
      %{priest: priest, ally: ally} = party_pair(catalysts: true)
      group_id = raise_sanctuary(priest)
      walk_in(ally, {151, 150})
      sp = current_sp(priest)
      flush_packets()

      cast(priest, @heal, 1, ally.character.id)
      assert_cast_refused(@heal, priest.character.id)

      clear_act_delay(priest)
      before = System.monotonic_time(:millisecond)
      cast(priest, @basilica, 1)

      assert eventually(fn -> SkillUnitStorage.get(group_id) == nil end)

      assert eventually(fn ->
               not StatusStorage.has_status?(:player, ally.character.id, :sc_basilica) and
                 not StatusStorage.has_status?(:player, priest.character.id, :sc_basilica_caster)
             end)

      state = get_player_state(priest.pid)
      assert state.stats.current_state.sp == sp
      assert state.act_delay_until >= before + 2_000
    end

    test "a song field grants nothing to a unit on a Basilica cell" do
      %{priest: priest, ally: ally} = party_pair(catalysts: true)
      raise_sanctuary(priest)
      walk_in(ally, {152, 150})

      bard = bard({155, 150})

      outsider =
        start_session(insert_character("outsider", %{last_x: 154, last_y: 150}), {154, 150})

      cast(bard, @whistle, 5)

      assert eventually(fn ->
               StatusStorage.has_status?(:player, outsider.character.id, :sc_whistle)
             end)

      refute StatusStorage.has_status?(:player, ally.character.id, :sc_whistle)
    end

    test "an enemy monster placed inside is pushed back out" do
      %{priest: priest} = party_pair(catalysts: true)
      group_id = raise_sanctuary(priest)
      mob = spawn_mob({158, 150})

      :sys.replace_state(mob.pid, fn state -> %{state | x: 151, y: 151, dir: 4} end)
      :ok = SpatialIndex.update_unit_position(:mob, mob.unit_id, 151, 151, @map)
      :ok = UnitRegistry.update_unit_state(:mob, mob.unit_id, get_mob_state(mob.pid))

      manager = ProcessTree.get({SkillUnitManager, :server})
      :ok = SkillUnitManager.tick(manager, SkillUnitStorage.get(group_id).next_tick_at)

      assert eventually(fn ->
               {:ok, {151, y, @map}} = SpatialIndex.get_unit_position(:mob, mob.unit_id)
               y == 149
             end)
    end

    test "expiry ends the field, the caster lock and every occupant status" do
      %{priest: priest, ally: ally} = party_pair(catalysts: true)
      group_id = raise_sanctuary(priest)
      walk_in(ally, {151, 150})

      manager = ProcessTree.get({SkillUnitManager, :server})
      :ok = SkillUnitManager.tick(manager, SkillUnitStorage.get(group_id).expires_at)

      assert eventually(fn ->
               SkillUnitStorage.get(group_id) == nil and
                 not StatusStorage.has_status?(:player, ally.character.id, :sc_basilica) and
                 not StatusStorage.has_status?(:player, priest.character.id, :sc_basilica_caster)
             end)

      assert Interpreter.can_move?(:player, priest.character.id)
    end
  end

  defp raise_sanctuary(priest) do
    cast(priest, @basilica, 1)

    assert eventually(fn ->
             StatusStorage.has_status?(:player, priest.character.id, :sc_basilica_caster)
           end)

    %{val2: group_id} =
      StatusStorage.get_status(:player, priest.character.id, :sc_basilica_caster)

    assert eventually(fn -> SkillUnitStorage.get(group_id) != nil end)
    group_id
  end

  # A real walk through the movement pipeline into the sanctuary.
  defp walk_in(session, {x, y}) do
    id = session.character.id
    simulate_incoming_message(session.pid, %MoveRequest{dest_x: x, dest_y: y})

    assert eventually(fn ->
             state = get_player_state(session.pid)

             {state.x, state.y} == {x, y} and
               StatusStorage.has_status?(:player, id, :sc_basilica)
           end)
  end

  defp melee_damage(priest, defender) do
    attacker = PlayerState.to_combatant(get_player_state(priest.pid))

    {:ok, %{damage: damage}} =
      DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

    damage
  end

  defp patient do
    character = insert_character("patient", %{class: 4008, base_level: 99, vit: 99, hp: 1})
    start_session(Repo.get(Character, character.id), {151, 150})
  end

  defp heal_once(healer, patient) do
    PlayerSession.set_vitals(patient.pid, hp: 1)
    assert eventually(fn -> current_hp(patient) == 1 end)

    clear_act_delay(healer)
    cast(healer, @heal, 10, patient.character.id)
    assert eventually(fn -> current_hp(patient) > 1 end)
    current_hp(patient) - 1
  end

  defp bard({x, y}) do
    character =
      insert_character("bard", %{
        class: 19,
        base_level: 99,
        job_level: 50,
        learned_skills: %{"1" => 9, "319" => 5},
        last_x: x,
        last_y: y
      })

    {:ok, _} =
      InventoryPersistence.insert_item(character.id, %{
        nameid: @violin,
        amount: 1,
        identify: 1,
        equip: @right_hand
      })

    start_session(character, {x, y})
  end

  defp heal_amount(healer), do: heal_once(healer, patient())

  defp equip!(session, item_id, position) do
    {index, _} =
      Enum.find(get_player_state(session.pid).inventory, fn {_i, item} ->
        item.nameid == item_id
      end)

    simulate_incoming_message(session.pid, %EquipItem{
      index: PlayerState.client_index(index),
      position: position
    })

    assert eventually(fn -> get_player_state(session.pid).inventory[index].equip == position end)
  end

  defp assert_cast_refused(skill_id, character_id) do
    assert_receive {:packet_sent, packet, _}, 1_000

    case packet do
      %SkillCastFailed{skill_id: ^skill_id} -> :ok
      %CastCancel{gid: ^character_id} -> :ok
      _other -> assert_cast_refused(skill_id, character_id)
    end
  end

  defp clear_act_delay(priest) do
    :sys.replace_state(priest.pid, fn session ->
      put_in(session.game_state.act_delay_until, 0)
    end)
  end

  defp force_hits do
    Mimic.copy(HitCalculations)
    Mimic.stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
  end

  defp spawn_mob(position, opts \\ []) do
    mob =
      start_mob_session(
        Keyword.merge(
          [map_name: @map, position: position, hp: 100_000, max_hp: 100_000, dex: 200],
          opts
        )
      )

    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)
    mob
  end

  # With catalysts the ally waits outside the 7x7 the sanctuary needs clear.
  defp party_pair(opts \\ []) do
    catalysts? = Keyword.get(opts, :catalysts, false)
    priest_char = insert_character("priest", high_priest_attrs(%{}))

    if catalysts?, do: give_items(priest_char, @catalysts)

    {:ok, _state} = PartyManager.create("Saints#{priest_char.id}", priest_char)
    party_id = Repo.get(Character, priest_char.id).party_id

    {ally_x, ally_y} = ally_position = if catalysts?, do: {160, 150}, else: {151, 150}

    ally_char =
      insert_character("ally", %{
        class: 0,
        base_level: 50,
        vit: 1,
        hp: 2_000,
        last_x: ally_x,
        last_y: ally_y
      })

    {:ok, _state} = PartyManager.add_member(party_id, ally_char)

    %{
      priest: start_session(Repo.get(Character, priest_char.id), {150, 150}),
      ally: start_session(Repo.get(Character, ally_char.id), ally_position)
    }
  end

  defp high_priest(opts \\ []) do
    learned = Keyword.get(opts, :learned)
    overrides = if learned, do: %{learned_skills: learned}, else: %{}
    character = insert_character("priest", high_priest_attrs(overrides))
    give_items(character, Keyword.get(opts, :items, []))
    start_session(character, {150, 150})
  end

  defp give_items(character, item_ids) do
    for item_id <- item_ids do
      {:ok, _} =
        InventoryPersistence.insert_item(character.id, %{nameid: item_id, amount: 1, identify: 1})
    end
  end

  defp high_priest_attrs(overrides) do
    Map.merge(
      %{
        class: @high_priest_class,
        base_level: 99,
        job_level: 50,
        str: 10,
        agi: 10,
        vit: 40,
        int: 99,
        dex: 99,
        luk: 10,
        hp: 5_000,
        max_hp: 5_000,
        sp: 1_000,
        max_sp: 1_000,
        learned_skills: %{
          "28" => 10,
          "73" => 10,
          "361" => 5,
          "362" => 5,
          "363" => 10,
          "481" => 5
        }
      },
      overrides
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

  defp cast(caster, skill_id, level, target_id \\ nil) do
    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id || caster.character.id
    })
  end

  defp holds?(session, item_id) do
    get_player_state(session.pid).inventory
    |> Enum.any?(fn {_index, item} -> item.nameid == item_id end)
  end

  defp current_hp(session), do: get_player_state(session.pid).stats.current_state.hp
  defp current_sp(session), do: get_player_state(session.pid).stats.current_state.sp
  defp max_sp(session), do: get_player_state(session.pid).stats.derived_stats.max_sp
end
