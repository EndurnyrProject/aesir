defmodule Aesir.ZoneServer.Integration.DancerActiveSkillsTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.Respawn
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Skills.Dancer.DcUglydance
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @map "dancer_active_a"
  @other_map "dancer_active_b"
  @dancer_class 20
  @throw_arrow 324
  @hip_shaker 325
  @dazzler 326
  @whip 1950
  @arrow 1750
  @right_hand 2
  @ammo 0x008000

  setup do
    Mimic.copy(HitCalculations)
    Mimic.copy(Resistance)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    stub(Resistance, :roll_success, fn _effective_rate -> true end)

    map_cache = EtsTable.table_for(:map_cache)
    :ets.insert(map_cache, {@map, MapData.new(@map, 200, 200)})
    :ets.insert(map_cache, {@other_map, MapData.new(@other_map, 200, 200)})

    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "Throw Arrow requires a whip and one arrow without partial consumption" do
    target = start_target({151, 150})
    no_whip = start_dancer([@throw_arrow], arrows: 3)
    initial_sp = player_sp(no_whip.pid)

    cast(no_whip, @throw_arrow, target.unit_id)

    assert_receive {:packet_sent,
                    %SkillCastFailed{
                      skill_id: @throw_arrow,
                      reason: :SKILL_CAST_FAILURE_REASON_WRONG_WEAPON
                    }, _},
                   1_000

    assert equipped_arrow_amount(no_whip.pid) == 3
    assert persisted_arrow_amount(no_whip.character.id) == 3
    assert player_sp(no_whip.pid) == initial_sp

    no_arrow = start_dancer([@throw_arrow], name: "NoArrow", whip?: true)
    initial_sp = player_sp(no_arrow.pid)

    cast(no_arrow, @throw_arrow, target.unit_id)

    assert_receive {:packet_sent,
                    %SkillCastFailed{
                      skill_id: @throw_arrow,
                      reason: :SKILL_CAST_FAILURE_REASON_NO_AMMO
                    }, _},
                   1_000

    assert equipped_arrow_amount(no_arrow.pid) == 0
    assert player_sp(no_arrow.pid) == initial_sp

    dancer = start_dancer([@throw_arrow], name: "Armed", whip?: true, arrows: 3)
    cast(dancer, @throw_arrow, target.unit_id)

    assert_receive {:packet_sent,
                    %SkillDamage{
                      skill_id: @throw_arrow,
                      target_id: target_id,
                      div: 2,
                      damage: damage
                    }, _},
                   2_000

    assert target_id == target.unit_id
    assert damage > 0
    assert eventually(fn -> equipped_arrow_amount(dancer.pid) == 2 end)
    assert eventually(fn -> persisted_arrow_amount(dancer.character.id) == 2 end)
  end

  test "Hip Shaker rejects a normal map with its versus-only reason" do
    dancer = start_dancer([@hip_shaker], whip?: true)
    state = get_player_state(dancer.pid)
    initial_sp = player_sp(dancer.pid)

    assert {:error, :versus_map_only} =
             DcUglydance.validate(state, :self, 1, DcUglydance.definition())

    cast(dancer, @hip_shaker, dancer.character.id)

    assert_receive {:packet_sent,
                    %SkillCastFailed{
                      skill_id: @hip_shaker,
                      reason: :SKILL_CAST_FAILURE_REASON_VERSUS_MAP_ONLY
                    }, _},
                   1_000

    assert player_sp(dancer.pid) == initial_sp
  end

  test "Dazzler resolves after three seconds with enemy and quarter-rate party chances" do
    %{dancer: dancer, ally: ally} = start_dancer_party()
    target = start_target({151, 150})
    test_pid = self()

    stub(Resistance, :apply_resistance, fn definition, _stats, chance, duration ->
      send(test_pid, {:resistance, definition.id, chance, duration})
      {chance, duration}
    end)

    cast(dancer, @dazzler, dancer.character.id, 5)

    refute StatusStorage.has_status?(:mob, target.unit_id, :sc_stun)
    refute StatusStorage.has_status?(:player, ally.character.id, :sc_stun)

    assert eventually(
             fn ->
               StatusStorage.has_status?(:mob, target.unit_id, :sc_stun) and
                 StatusStorage.has_status?(:player, ally.character.id, :sc_stun)
             end,
             4_000
           )

    assert_received {:resistance, :sc_stun, 50, 4_500}
    assert_received {:resistance, :sc_stun, 12.5, 4_500}

    assert %{expires_at: enemy_expiry} =
             StatusStorage.get_status(:mob, target.unit_id, :sc_stun)

    assert %{expires_at: party_expiry} =
             StatusStorage.get_status(:player, ally.character.id, :sc_stun)

    assert abs(enemy_expiry - party_expiry) < 100
  end

  test "Dazzler timers abort on death, disconnect, map change, and same-map relocation" do
    death = dazzler_pair("Death", {140, 140})
    disconnect = dazzler_pair("Disconnect", {145, 140})
    cross_map = dazzler_pair("CrossMap", {150, 140})
    same_map = dazzler_pair("SameMap", {155, 140})
    pairs = [death, disconnect, cross_map, same_map]

    Enum.each(pairs, fn %{dancer: dancer} ->
      initial_sp = player_sp(dancer.pid)
      cast(dancer, @dazzler, dancer.character.id, 5)
      assert eventually(fn -> player_sp(dancer.pid) == initial_sp - 20 end)
    end)

    hp = get_player_state(death.dancer.pid).stats.current_state.hp
    PlayerSession.apply_damage(death.dancer.pid, hp, nil)
    assert eventually(fn -> get_player_state(death.dancer.pid).action_state == :dead end)
    simulate_incoming_message(death.dancer.pid, %Respawn{type: 0})
    assert eventually(fn -> get_player_state(death.dancer.pid).action_state == :idle end)

    end_player_session(disconnect.dancer)
    assert eventually(fn -> not Process.alive?(disconnect.dancer.pid) end)

    PlayerSession.warp(cross_map.dancer.pid, @other_map, 160, 160)
    assert eventually(fn -> get_player_state(cross_map.dancer.pid).map_name == @other_map end)

    PlayerSession.warp(same_map.dancer.pid, @map, 160, 140)
    assert eventually(fn -> player_position(same_map.dancer.pid) == {160, 140} end)

    Process.sleep(3_200)

    Enum.each(pairs, fn %{target: target} ->
      refute StatusStorage.has_status?(:mob, target.unit_id, :sc_stun)
    end)
  end

  defp dazzler_pair(name, {x, y}) do
    dancer = start_dancer([@dazzler], name: name, position: {x, y})
    target = start_target({x + 1, y})
    %{dancer: dancer, target: target}
  end

  defp start_dancer_party do
    dancer_character = insert_dancer("PartyLead", [@dazzler], {150, 150})
    {:ok, party} = PartyManager.create("Dazzler#{dancer_character.id}", dancer_character)

    ally_character = insert_character("PartyAlly", [], {149, 150}, class: 0)
    {:ok, _party} = PartyManager.add_member(party.party_id, ally_character)

    dancer = start_session(Repo.get!(Character, dancer_character.id), {150, 150})
    ally = start_session(Repo.get!(Character, ally_character.id), {149, 150})
    %{dancer: dancer, ally: ally}
  end

  defp start_dancer(skill_ids, opts) do
    position = Keyword.get(opts, :position, {150, 150})
    character = insert_dancer(Keyword.get(opts, :name, "Dancer"), skill_ids, position)

    if Keyword.get(opts, :whip?, false) do
      seed_inventory(character.id, nameid: @whip, amount: 1, equip: @right_hand)
    end

    case Keyword.get(opts, :arrows, 0) do
      0 -> :ok
      amount -> seed_inventory(character.id, nameid: @arrow, amount: amount, equip: @ammo)
    end

    start_session(character, position)
  end

  defp start_session(character, position) do
    session = start_player_session(character: character, map_name: @map, position: position)
    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp start_target(position) do
    target =
      start_mob_session(
        unit_id: System.unique_integer([:positive]),
        map_name: @map,
        position: position,
        hp: 50_000,
        max_hp: 50_000,
        vit: 0,
        luk: 0
      )

    on_exit(fn ->
      StatusStorage.clear_unit_statuses(:mob, target.unit_id)
      end_mob_session(target)
    end)

    target
  end

  defp insert_dancer(name, skill_ids, position) do
    insert_character(name, skill_ids, position, class: @dancer_class)
  end

  defp insert_character(name, skill_ids, {x, y}, opts) do
    unique = System.unique_integer([:positive])
    userid = "danceractive#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "F",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    learned_skills = Map.new(skill_ids, &{Integer.to_string(&1), 5})

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{unique}",
        class: Keyword.fetch!(opts, :class),
        base_level: 99,
        job_level: 50,
        str: 20,
        agi: 20,
        vit: 20,
        int: 20,
        dex: 99,
        luk: 20,
        hp: 5_000,
        max_hp: 5_000,
        sp: 500,
        max_sp: 500,
        learned_skills: learned_skills,
        last_map: @map,
        last_x: x,
        last_y: y,
        save_map: @map,
        save_x: x,
        save_y: y
      }
      |> Character.new()
      |> Repo.insert()

    character
  end

  defp seed_inventory(char_id, attrs) do
    attrs = attrs |> Map.new() |> Map.put_new(:identify, 1)
    {:ok, item} = InventoryPersistence.insert_item(char_id, attrs)
    item
  end

  defp cast(session, skill_id, target_id, level \\ 1) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id
    })
  end

  defp equipped_arrow_amount(pid) do
    pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Map.values()
    |> Enum.find_value(0, fn
      %InventoryItem{nameid: @arrow, equip: @ammo, amount: amount} -> amount
      _item -> nil
    end)
  end

  defp persisted_arrow_amount(character_id) do
    character_id
    |> InventoryPersistence.load_inventory()
    |> Enum.find_value(0, fn
      %InventoryItem{nameid: @arrow, equip: @ammo, amount: amount} -> amount
      _item -> nil
    end)
  end

  defp player_sp(pid), do: get_player_state(pid).stats.current_state.sp
  defp player_position(pid), do: then(get_player_state(pid), &{&1.x, &1.y})
end
