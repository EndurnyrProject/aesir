defmodule Aesir.ZoneServer.Integration.DancerDanceSnapshotIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  import Ecto.Query

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.CharacterStatus
  alias Aesir.Net.PartyActionResult
  alias Aesir.Net.PartyCreateRequest
  alias Aesir.Net.PartyInviteNotify
  alias Aesir.Net.PartyInviteRequest
  alias Aesir.Net.PartyInviteResponse
  alias Aesir.Net.Respawn
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "dancer_snapshot_a"
  @other_map "dancer_snapshot_b"
  @origin {150, 150}
  @violin 1901
  @whip 1960
  @right_hand 2
  @bragi 321
  @focus_ballet 327
  @slow_grace 328
  @gypsy_kiss 330

  setup do
    map_cache = EtsTable.table_for(:map_cache)
    :ets.insert(map_cache, {@map, MapData.new(@map, 200, 200)})
    :ets.insert(map_cache, {@other_map, MapData.new(@other_map, 200, 200)})

    on_exit(fn ->
      ClusterTestHelper.clear_all()
      :ets.delete(map_cache, @map)
      :ets.delete(map_cache, @other_map)
    end)

    :ok
  end

  test "Bard and Dancer buffs stack, and a second dance replaces only the dance" do
    bard = start_performer("Bard", :bard, @origin, [@bragi])
    dancer = start_performer("Dancer", :dancer, {151, 150}, [@gypsy_kiss, @focus_ballet])
    recipient = start_recipient("Recipient", {152, 150})
    create_party(bard, [dancer, recipient])

    cast(bard, @bragi, 10)
    assert_status(recipient, :sc_poembragi)

    cast(dancer, @gypsy_kiss, 10)
    assert_status(recipient, :sc_serviceforyou)
    assert StatusStorage.has_status?(:player, recipient.character.id, :sc_poembragi)

    wait_for_act_ready(dancer.pid)
    cast(dancer, @focus_ballet, 10)
    assert_status(recipient, :sc_humming)

    refute StatusStorage.has_status?(:player, recipient.character.id, :sc_serviceforyou)
    assert StatusStorage.has_status?(:player, recipient.character.id, :sc_poembragi)
  end

  test "party and enemy snapshots use disjoint recipients and radii" do
    dancer = start_performer("Scope", :dancer, @origin, [@focus_ballet, @slow_grace])
    recipient = start_recipient("Party", {165, 150})
    create_party(dancer, [recipient])

    enemy =
      start_mob_session(
        unit_id: System.unique_integer([:positive]),
        map_name: @map,
        position: {154, 150},
        hp: 50_000,
        max_hp: 50_000
      )

    enemy_state = get_mob_state(enemy.pid)
    stats = Map.merge(enemy_state.mob_data.stats, %{vit: 0, luk: 0})
    mob_data = %{enemy_state.mob_data | stats: stats}

    assert :ok =
             UnitRegistry.update_unit_state(:mob, enemy.unit_id, %{
               enemy_state
               | mob_data: mob_data
             })

    on_exit(fn -> end_mob_session(enemy) end)

    cast(dancer, @focus_ballet, 1)
    assert_status(recipient, :sc_humming)
    refute StatusStorage.has_status?(:mob, enemy.unit_id, :sc_humming)

    wait_for_act_ready(dancer.pid)
    cast(dancer, @slow_grace, 1)

    assert eventually(fn ->
             StatusStorage.has_status?(:mob, enemy.unit_id, :sc_dontforgetme)
           end)

    refute StatusStorage.has_status?(:player, recipient.character.id, :sc_dontforgetme)
    assert StatusStorage.has_status?(:player, recipient.character.id, :sc_humming)
  end

  test "a dance survives damage, death, map change, Dispel, and relog with bounded duration" do
    dancer = start_performer("Lifecycle", :dancer, @origin, [@focus_ballet])
    char_id = dancer.character.id

    cast(dancer, @focus_ballet, 1)
    assert_status(dancer, :sc_humming)

    PlayerSession.apply_damage(dancer.pid, 1, nil)
    assert eventually(fn -> get_player_state(dancer.pid).stats.current_state.hp == 499 end)
    assert StatusStorage.has_status?(:player, char_id, :sc_humming)

    assert :ok = Dispel.dispel({:player, char_id})
    assert StatusStorage.has_status?(:player, char_id, :sc_humming)

    PlayerSession.warp(dancer.pid, @other_map, 160, 160)
    assert eventually(fn -> get_player_state(dancer.pid).map_name == @other_map end)
    assert StatusStorage.has_status?(:player, char_id, :sc_humming)

    hp = get_player_state(dancer.pid).stats.current_state.hp
    PlayerSession.apply_damage(dancer.pid, hp, nil)
    assert eventually(fn -> get_player_state(dancer.pid).action_state == :dead end)
    assert StatusStorage.has_status?(:player, char_id, :sc_humming)

    simulate_incoming_message(dancer.pid, %Respawn{type: 0})
    assert eventually(fn -> get_player_state(dancer.pid).action_state == :idle end)

    shorten_status(char_id, 2_000)
    end_player_session(dancer)
    assert eventually(fn -> not Process.alive?(dancer.pid) end)

    assert [%CharacterStatus{status_type: "sc_humming", remaining_ms: saved_ms}] =
             Repo.all(from row in CharacterStatus, where: row.char_id == ^char_id)

    assert saved_ms in 1..2_000

    restored =
      start_player_session(
        character: Repo.get!(Character, char_id),
        map_name: @other_map,
        position: {160, 160}
      )

    on_exit(fn -> end_player_session(restored) end)

    assert_status(restored, :sc_humming)
    status = StatusStorage.get_status(:player, char_id, :sc_humming)
    remaining_ms = status.expires_at - System.monotonic_time(:millisecond)
    assert remaining_ms in 1..saved_ms
  end

  defp create_party(owner, members) do
    simulate_incoming_message(owner.pid, %PartyCreateRequest{name: "Performers"})
    assert_receive {:packet_sent, %PartyActionResult{action: "create", success: true}, _}, 1_000
    party_id = Repo.get!(Character, owner.character.id).party_id
    Enum.each(members, &invite(owner, &1, party_id))
    flush_packets()
  end

  defp invite(owner, recipient, party_id) do
    simulate_incoming_message(owner.pid, %PartyInviteRequest{
      target_char_id: recipient.character.id,
      target_name: ""
    })

    assert_receive {:packet_sent, %PartyActionResult{action: "invite", success: true}, _}, 1_000
    assert_receive {:packet_sent, %PartyInviteNotify{party_id: ^party_id}, _}, 1_000

    simulate_incoming_message(recipient.pid, %PartyInviteResponse{
      party_id: party_id,
      accept: true
    })

    assert_receive {:packet_sent, %PartyActionResult{action: "invite_response", success: true},
                    _},
                   1_000

    assert get_player_state(recipient.pid).party_id == party_id
  end

  defp start_performer(name, job, position, skill_ids) do
    character = insert_character(name, job, position, skill_ids)
    equip_weapon(character.id, if(job == :dancer, do: @whip, else: @violin))
    start_player_session(character: character, map_name: @map, position: position)
  end

  defp start_recipient(name, position) do
    character = insert_character(name, :novice, position, [])
    start_player_session(character: character, map_name: @map, position: position)
  end

  defp insert_character(name, job, {x, y}, skill_ids) do
    unique = System.unique_integer([:positive])
    userid = "dance#{unique}"
    sex = if job == :dancer, do: "F", else: "M"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: sex,
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{unique}",
        class: %{novice: 0, bard: 19, dancer: 20}[job],
        base_level: 99,
        job_level: 50,
        hp: 500,
        max_hp: 500,
        sp: 500,
        max_sp: 500,
        learned_skills: Map.new(skill_ids, &{Integer.to_string(&1), 10}),
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

  defp cast(session, skill_id, level) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: session.character.id
    })
  end

  defp assert_status(session, status_id) do
    assert eventually(fn ->
             StatusStorage.has_status?(:player, session.character.id, status_id)
           end)
  end

  defp wait_for_act_ready(pid) do
    assert eventually(fn ->
             PlayerState.act_ready?(get_player_state(pid), System.monotonic_time(:millisecond))
           end)
  end

  defp shorten_status(char_id, duration_ms) do
    assert :ok =
             StatusStorage.update_status(:player, char_id, :sc_humming, fn status ->
               %{status | expires_at: System.monotonic_time(:millisecond) + duration_ms}
             end)
  end

  defp equip_weapon(char_id, weapon_id) do
    {:ok, _item} =
      InventoryPersistence.insert_item(char_id, %{
        nameid: weapon_id,
        amount: 1,
        identify: 1,
        equip: @right_hand
      })
  end
end
