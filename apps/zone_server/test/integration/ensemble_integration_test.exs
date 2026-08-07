defmodule Aesir.ZoneServer.Integration.EnsembleIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.CastCancel
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "ensemble_integration"
  @origin {150, 150}
  @bard_class 19
  @dancer_class 20
  @violin 1901
  @whip 1950
  @right_hand 2
  @first_aid 142
  @drum 309
  @siegfried 313
  @fatigue :sc_ensemblefatigue

  setup do
    map_cache = EtsTable.table_for(:map_cache)
    :ets.insert(map_cache, {@map, MapData.new(@map, 200, 200)})

    on_exit(fn ->
      ClusterTestHelper.clear_all()
    end)

    :ok
  end

  test "a Bard and Dancer pair at the averaged level and both become fatigued" do
    %{bard: bard, dancer: dancer, nearby: nearby, far: far} = start_full_party()
    baseline = get_player_state(nearby.pid).stats.combat_stats

    cast(bard, @drum, 5)

    assert eventually(fn -> status_level(nearby, :sc_drumbattle) == 3 end)
    assert eventually(fn -> cast_finished?(bard) end)

    assert eventually(fn ->
             stats = get_player_state(nearby.pid).stats.combat_stats
             stats.atk == baseline.atk + 30 and stats.def == baseline.def + 45
           end)

    assert eventually(fn -> has_status?(bard, @fatigue) end)
    assert eventually(fn -> has_status?(dancer, @fatigue) end)
    refute has_status?(nearby, @fatigue)
    refute has_status?(far, :sc_drumbattle)

    PlayerSession.apply_damage(bard.pid, 10)
    assert eventually(fn -> current_hp(bard) == bard.character.hp - 10 end)
    sp = current_sp(bard)
    flush_packets()

    cast(bard, @first_aid, 1)

    assert_receive {:packet_sent, %CastCancel{gid: gid}, _}, 1_000
    assert gid == bard.character.id

    assert current_hp(bard) == bard.character.hp - 10
    assert current_sp(bard) == sp
  end

  test "the same Bard casts solo at his own level without fatiguing anyone" do
    %{bard: bard, nearby: nearby, far: far} = start_solo_party([@drum])

    cast(bard, @drum, 5)

    assert eventually(fn -> status_level(nearby, :sc_drumbattle) == 5 end)
    assert eventually(fn -> cast_finished?(bard) end)
    refute has_status?(bard, @fatigue)
    refute has_status?(nearby, @fatigue)
    refute has_status?(far, @fatigue)
    refute has_status?(far, :sc_drumbattle)
  end

  for rejection <- [:different_party, :wrong_weapon, :sitting, :skill_not_learned] do
    @rejection rejection

    test "#{rejection} partner degrades the ensemble to a successful solo cast" do
      %{bard: bard, dancer: dancer} = start_ineligible_pair(@rejection)

      cast(bard, @drum, 5)

      assert eventually(fn -> status_level(bard, :sc_drumbattle) == 5 end)
      assert eventually(fn -> cast_finished?(bard) end)
      refute has_status?(bard, @fatigue)
      refute has_status?(dancer, @fatigue)

      if @rejection == :different_party do
        refute has_status?(dancer, :sc_drumbattle)
      else
        assert eventually(fn -> status_level(dancer, :sc_drumbattle) == 5 end)
      end
    end
  end

  test "a second buff ensemble replaces the first on recipients" do
    %{bard: bard, nearby: nearby} = start_solo_party([@drum, @siegfried])

    cast(bard, @drum, 5)
    assert eventually(fn -> has_status?(nearby, :sc_drumbattle) end)
    assert eventually(fn -> act_ready?(bard) end)

    cast(bard, @siegfried, 5)

    assert eventually(fn -> has_status?(nearby, :sc_siegfried) end)
    refute has_status?(bard, :sc_drumbattle)
    refute has_status?(nearby, :sc_drumbattle)
    assert has_status?(bard, :sc_siegfried)
  end

  defp start_full_party do
    bard_character = insert_character("PairBard", :bard, @origin, %{@drum => 5, @first_aid => 1})
    dancer_character = insert_character("PairDancer", :dancer, {151, 150}, %{@drum => 1})
    nearby_character = insert_character("PairNear", :novice, {155, 150}, %{})
    far_character = insert_character("PairFar", :novice, {170, 150}, %{})

    party([bard_character, dancer_character, nearby_character, far_character])
    equip(bard_character, @violin)
    equip(dancer_character, @whip)

    %{
      bard: start_session(bard_character, @origin),
      dancer: start_session(dancer_character, {151, 150}),
      nearby: start_session(nearby_character, {155, 150}),
      far: start_session(far_character, {170, 150})
    }
  end

  defp start_solo_party(skill_ids) do
    learned = Map.new(skill_ids, &{&1, 5})
    bard_character = insert_character("SoloBard", :bard, @origin, learned)
    nearby_character = insert_character("SoloNear", :novice, {155, 150}, %{})
    far_character = insert_character("SoloFar", :novice, {170, 150}, %{})

    party([bard_character, nearby_character, far_character])
    equip(bard_character, @violin)

    %{
      bard: start_session(bard_character, @origin),
      nearby: start_session(nearby_character, {155, 150}),
      far: start_session(far_character, {170, 150})
    }
  end

  defp start_ineligible_pair(rejection) do
    dancer_skills = if rejection == :skill_not_learned, do: %{}, else: %{@drum => 1}
    bard_character = insert_character("RejectBard", :bard, @origin, %{@drum => 5})
    dancer_character = insert_character("RejectDancer", :dancer, {151, 150}, dancer_skills)

    if rejection == :different_party do
      party([bard_character])
      party([dancer_character])
    else
      party([bard_character, dancer_character])
    end

    equip(bard_character, @violin)

    if rejection != :wrong_weapon do
      equip(dancer_character, @whip)
    end

    bard = start_session(bard_character, @origin)
    dancer = start_session(dancer_character, {151, 150})

    if rejection == :sitting do
      set_action_state(dancer, :sitting)
    end

    %{bard: bard, dancer: dancer}
  end

  defp party([leader | members]) do
    {:ok, party} = PartyManager.create("Ensemble#{leader.id}", leader)

    Enum.each(members, fn member ->
      {:ok, _party} = PartyManager.add_member(party.party_id, member)
    end)
  end

  defp start_session(character, position) do
    session =
      start_player_session(
        character: Repo.get!(Character, character.id),
        map_name: @map,
        position: position
      )

    on_exit(fn -> end_player_session(session) end)
    assert eventually(fn -> get_player_state(session.pid).action_state == :idle end)
    session
  end

  defp set_action_state(session, action_state) do
    session_state =
      :sys.replace_state(session.pid, fn state ->
        %{state | game_state: %{state.game_state | action_state: action_state}}
      end)

    :ok = UnitRegistry.update_unit_state(:player, session.character.id, session_state.game_state)
  end

  defp insert_character(name, job, {x, y}, learned_skills) do
    unique = System.unique_integer([:positive])
    userid = "ensemble#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: if(job == :dancer, do: "F", else: "M"),
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{unique}",
        class: %{novice: 0, bard: @bard_class, dancer: @dancer_class}[job],
        base_level: 99,
        job_level: 50,
        str: 20,
        agi: 20,
        vit: 20,
        int: 20,
        dex: 20,
        luk: 20,
        hp: 500,
        max_hp: 500,
        sp: 500,
        max_sp: 500,
        learned_skills:
          Map.new(learned_skills, fn {id, level} -> {Integer.to_string(id), level} end),
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

  defp equip(character, nameid) do
    {:ok, _item} =
      InventoryPersistence.insert_item(character.id, %{
        nameid: nameid,
        amount: 1,
        identify: 1,
        equip: @right_hand
      })
  end

  defp cast(session, skill_id, level) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: session.character.id
    })
  end

  defp status_level(session, status_id) do
    case StatusStorage.get_status(:player, session.character.id, status_id) do
      nil -> nil
      status -> status.val1
    end
  end

  defp has_status?(session, status_id),
    do: StatusStorage.has_status?(:player, session.character.id, status_id)

  defp current_hp(session), do: get_player_state(session.pid).stats.current_state.hp
  defp current_sp(session), do: get_player_state(session.pid).stats.current_state.sp

  defp cast_finished?(session), do: get_player_state(session.pid).action_state == :idle

  defp act_ready?(session) do
    PlayerState.act_ready?(get_player_state(session.pid), System.monotonic_time(:millisecond))
  end
end
