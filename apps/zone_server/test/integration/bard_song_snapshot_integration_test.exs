defmodule Aesir.ZoneServer.Integration.BardSongSnapshotIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  import Ecto.Query

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.CharacterStatus
  alias Aesir.Net.MoveRequest
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
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "bard_song_a"
  @other_map "bard_song_b"
  @origin {150, 150}
  @violin 1901
  @right_hand 2
  @whistle 319
  @sunset 320
  @bragi 321
  @idun 322

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

  test "each song snapshots the live party, refreshes recipient stats, and replaces songs" do
    %{caster: caster, nearby: nearby, moving: moving} = start_song_party()
    nearby_id = nearby.character.id
    moving_id = moving.character.id

    baselines = %{
      flee: song_reader(nearby.pid, :flee),
      aspd: song_reader(nearby.pid, :aspd),
      max_hp: song_reader(nearby.pid, :max_hp)
    }

    songs = [
      {@whistle, :sc_whistle, :flee},
      {@sunset, :sc_assncross, :aspd},
      {@bragi, :sc_poembragi, :bragi},
      {@idun, :sc_appleidun, :max_hp}
    ]

    Enum.reduce(songs, nil, fn {skill_id, status_id, reader}, previous_status ->
      reset_recipient(nearby, moving, baselines)

      if skill_id == @sunset do
        refute StatusStorage.has_status?(:player, nearby_id, :sc_quagmire)
        assert get_player_state(nearby.pid).option == 0
      end

      PlayerSession.warp(moving.pid, @map, 165, 150)
      assert eventually(fn -> position(moving.pid) == {165, 150} end)
      assert_act_ready(caster.pid)

      cast(caster, skill_id, 10)
      PlayerSession.warp(moving.pid, @map, 180, 180)

      assert eventually(fn -> position(moving.pid) == {180, 180} end)
      assert eventually(fn -> StatusStorage.has_status?(:player, nearby_id, status_id) end)
      assert StatusStorage.has_status?(:player, caster.character.id, status_id)
      refute StatusStorage.has_status?(:player, moving_id, status_id)

      if previous_status do
        refute StatusStorage.has_status?(:player, caster.character.id, previous_status)
      end

      assert eventually(fn ->
               get_player_state(nearby.pid).stats.modifiers.statuses_active?
             end)

      assert_song_reader(nearby, reader, baselines)
      status_id
    end)
  end

  test "a finite song survives movement, death, map change, relog, and expires" do
    character = insert_character("Lifecycle", bard?: true)
    equip_violin(character.id)
    session = start_player_session(character: character, map_name: @map, position: @origin)
    char_id = character.id
    baseline_flee = get_player_state(session.pid).stats.combat_stats.flee

    cast(session, @whistle)
    assert eventually(fn -> StatusStorage.has_status?(:player, char_id, :sc_whistle) end)
    assert_finite_song(char_id, 180_000)

    simulate_incoming_message(session.pid, %MoveRequest{dest_x: 151, dest_y: 150})
    assert eventually(fn -> position(session.pid) == {151, 150} end)
    assert StatusStorage.has_status?(:player, char_id, :sc_whistle)

    PlayerSession.warp(session.pid, @other_map, 160, 160)
    assert eventually(fn -> player_map(session.pid) == @other_map end)
    assert StatusStorage.has_status?(:player, char_id, :sc_whistle)

    hp = get_player_state(session.pid).stats.current_state.hp
    PlayerSession.apply_damage(session.pid, hp, nil)

    assert eventually(fn -> get_player_state(session.pid).action_state == :dead end)
    assert StatusStorage.has_status?(:player, char_id, :sc_whistle)

    simulate_incoming_message(session.pid, %Respawn{type: 0})
    assert eventually(fn -> get_player_state(session.pid).action_state == :idle end)
    assert StatusStorage.has_status?(:player, char_id, :sc_whistle)

    shorten_song(char_id, 2_000)
    end_player_session(session)

    assert eventually(fn -> not Process.alive?(session.pid) end)
    refute StatusStorage.has_status?(:player, char_id, :sc_whistle)

    assert [%CharacterStatus{status_type: "sc_whistle", remaining_ms: saved_ms}] =
             Repo.all(from row in CharacterStatus, where: row.char_id == ^char_id)

    assert saved_ms in 1..2_000

    restored_character = Repo.get!(Character, char_id)

    restored =
      start_player_session(
        character: restored_character,
        map_name: @other_map,
        position: {160, 160}
      )

    on_exit(fn -> end_player_session(restored) end)

    assert eventually(fn -> StatusStorage.has_status?(:player, char_id, :sc_whistle) end)
    assert_finite_song(char_id, saved_ms)

    assert eventually(fn ->
             get_player_state(restored.pid).stats.combat_stats.flee == baseline_flee + 20
           end)

    expire_song(char_id)
    StatusTickManager.force_tick()

    assert eventually(fn -> not StatusStorage.has_status?(:player, char_id, :sc_whistle) end)

    assert eventually(fn ->
             get_player_state(restored.pid).stats.combat_stats.flee == baseline_flee
           end)
  end

  defp start_song_party do
    caster_character = insert_character("Caster", bard?: true)
    nearby_character = insert_character("Nearby")
    moving_character = insert_character("Moving")
    equip_violin(caster_character.id)

    caster = start_player_session(character: caster_character, map_name: @map, position: @origin)

    nearby =
      start_player_session(character: nearby_character, map_name: @map, position: {160, 150})

    moving =
      start_player_session(character: moving_character, map_name: @map, position: {165, 150})

    simulate_incoming_message(caster.pid, %PartyCreateRequest{name: "Snapshot"})
    assert_receive {:packet_sent, %PartyActionResult{action: "create", success: true}, _}, 1_000

    party_id = Repo.get!(Character, caster.character.id).party_id
    invite(caster, nearby, party_id)
    invite(caster, moving, party_id)
    flush_packets()

    %{caster: caster, nearby: nearby, moving: moving}
  end

  defp invite(caster, recipient, party_id) do
    simulate_incoming_message(caster.pid, %PartyInviteRequest{
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

  defp cast(session, skill_id, level \\ 1) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: session.character.id
    })
  end

  defp reset_recipient(nearby, moving, baselines) do
    for session <- [nearby, moving] do
      StatusInterpreter.remove_all_statuses(:player, session.character.id, owner_refresh: :notify)
    end

    assert eventually(fn ->
             stats = get_player_state(nearby.pid).stats

             not stats.modifiers.statuses_active? and
               song_reader(nearby.pid, :flee) == baselines.flee and
               song_reader(nearby.pid, :aspd) == baselines.aspd and
               song_reader(nearby.pid, :max_hp) == baselines.max_hp
           end)
  end

  defp assert_song_reader(session, :flee, baselines) do
    assert eventually(fn -> song_reader(session.pid, :flee) == baselines.flee + 38 end)
  end

  defp assert_song_reader(session, :aspd, baselines) do
    assert eventually(fn -> song_reader(session.pid, :aspd) > baselines.aspd end)
  end

  defp assert_song_reader(session, :max_hp, baselines) do
    assert eventually(fn -> song_reader(session.pid, :max_hp) > baselines.max_hp end)
  end

  defp assert_song_reader(session, :bragi, _baselines) do
    assert eventually(fn ->
             case StatusStorage.get_status(:player, session.character.id, :sc_poembragi) do
               %{state: %{cast_time_reduction: 20, delay_reduction: 30}} -> true
               _status -> false
             end
           end)
  end

  defp song_reader(pid, :flee), do: get_player_state(pid).stats.combat_stats.flee
  defp song_reader(pid, :aspd), do: get_player_state(pid).stats.derived_stats.aspd
  defp song_reader(pid, :max_hp), do: get_player_state(pid).stats.derived_stats.max_hp

  defp assert_act_ready(pid) do
    assert eventually(fn ->
             PlayerState.act_ready?(get_player_state(pid), System.monotonic_time(:millisecond))
           end)
  end

  defp assert_finite_song(char_id, maximum_ms) do
    song = StatusStorage.get_status(:player, char_id, :sc_whistle)
    remaining_ms = song.expires_at - System.monotonic_time(:millisecond)

    assert remaining_ms > 0
    assert remaining_ms <= maximum_ms
    song
  end

  defp shorten_song(char_id, duration_ms) do
    assert :ok =
             StatusStorage.update_status(:player, char_id, :sc_whistle, fn song ->
               %{song | expires_at: System.monotonic_time(:millisecond) + duration_ms}
             end)
  end

  defp expire_song(char_id) do
    assert :ok =
             StatusStorage.update_status(:player, char_id, :sc_whistle, fn song ->
               %{song | expires_at: System.monotonic_time(:millisecond) - 1}
             end)
  end

  defp position(pid) do
    state = get_player_state(pid)
    {state.x, state.y}
  end

  defp player_map(pid), do: get_player_state(pid).map_name

  defp equip_violin(char_id) do
    {:ok, _item} =
      InventoryPersistence.insert_item(char_id, %{
        nameid: @violin,
        amount: 1,
        identify: 1,
        equip: @right_hand
      })
  end

  defp insert_character(name, opts \\ []) do
    unique = System.unique_integer([:positive])
    userid = "song#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    bard? = Keyword.get(opts, :bard?, false)

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{unique}",
        class: if(bard?, do: 19, else: 0),
        base_level: 99,
        job_level: 50,
        dex: 10,
        agi: 10,
        hp: 500,
        max_hp: 500,
        sp: 500,
        max_sp: 500,
        learned_skills:
          if(bard?,
            do: Map.new([@whistle, @sunset, @bragi, @idun], &{Integer.to_string(&1), 10}),
            else: %{}
          ),
        last_map: @map,
        last_x: elem(@origin, 0),
        last_y: elem(@origin, 1),
        save_map: @map,
        save_x: elem(@origin, 0),
        save_y: elem(@origin, 1)
      }
      |> Character.new()
      |> Repo.insert()

    character
  end
end
