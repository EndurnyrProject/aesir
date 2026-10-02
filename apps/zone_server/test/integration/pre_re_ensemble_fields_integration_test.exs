defmodule Aesir.ZoneServer.Integration.PreReEnsembleFieldsIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log
  @moduletag game_mode: :pre_renewal, integration_re: false

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillUnitSpawn
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.Unit, as: SkillUnit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence

  @map "prontera"

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 200, 200)})
    :ok
  end

  test "Drum places a visible stationary field and locks both performers at their averaged level" do
    %{bard: bard, dancer: dancer, guest: guest} = start_party(309, 5, 1)
    bard_id = bard.character.id
    dancer_id = dancer.character.id

    cast(bard, 309, 5)

    assert_eventually(fn -> match?([_], Storage.get_groups_by_caster(:player, bard_id)) end)
    [group] = Storage.get_groups_by_caster(:player, bard_id)
    assert group.skill_id == 309
    assert group.level == 3
    assert group.center == {150, 150}
    assert length(group.cells) == 81
    assert group.expires_at - group.created_at == 60_000
    refute Group.follows_caster?(group)

    assert_eventually(fn ->
      match?(%{val4: ^dancer_id}, StatusStorage.get_status(:player, bard_id, :sc_dancing)) and
        match?(%{val4: ^bard_id}, StatusStorage.get_status(:player, dancer_id, :sc_dancing))
    end)

    refute StatusInterpreter.can_move?(:player, bard_id)
    refute StatusInterpreter.can_move?(:player, dancer_id)
    refute StatusStorage.has_status?(:player, bard_id, :sc_ensemblefatigue)
    refute StatusStorage.has_status?(:player, dancer_id, :sc_ensemblefatigue)
    refute StatusStorage.has_status?(:player, bard_id, :sc_drumbattle)
    refute StatusStorage.has_status?(:player, dancer_id, :sc_drumbattle)

    assert_eventually(fn ->
      match?(
        %{val1: 3, expires_at: nil},
        StatusStorage.get_status(:player, guest.character.id, :sc_drumbattle)
      )
    end)

    assert_packet_sent(SkillUnitSpawn)
  end

  for {skill_id, level, upkeep} <- [
        {306, 1, 4},
        {307, 5, 3},
        {308, 1, 4},
        {310, 5, 3},
        {311, 1, 4},
        {312, 1, 5},
        {313, 5, 3}
      ] do
    test "ensemble #{skill_id} creates a field with its own upkeep" do
      %{bard: bard, dancer: dancer} =
        start_party(unquote(skill_id), unquote(level), unquote(level))

      cast(bard, unquote(skill_id), unquote(level))

      assert_eventually(fn ->
        match?([_], Storage.get_groups_by_caster(:player, bard.character.id))
      end)

      [group] = Storage.get_groups_by_caster(:player, bard.character.id)
      assert group.skill_id == unquote(skill_id)
      assert length(group.cells) == 81

      for performer <- [bard, dancer] do
        assert_eventually(fn ->
          match?(
            %{state: %{upkeep: unquote(upkeep)}},
            StatusStorage.get_status(:player, performer.character.id, :sc_dancing)
          )
        end)
      end
    end
  end

  test "a missing adjacent partner fails without spending SP or remembering a song" do
    bard = character(:bard, {150, 150}, %{309 => 5}) |> start_session()
    before = get_player_state(bard.pid)
    flush_packets()
    cast(bard, 309, 5)
    assert_packet_sent(SkillCastFailed)
    after_cast = get_player_state(bard.pid)
    assert after_cast.stats.current_state.sp == before.stats.current_state.sp
    assert after_cast.last_song == before.last_song
    assert Storage.get_groups_by_caster(:player, bard.character.id) == []
  end

  test "leaving an ensemble removes its buff immediately and re-entry restores it" do
    %{bard: bard, guest: guest} = start_party(309, 5, 5)
    cast(bard, 309, 5)

    assert_eventually(fn ->
      StatusStorage.has_status?(:player, guest.character.id, :sc_drumbattle)
    end)

    simulate_incoming_message(guest.pid, %MoveRequest{dest_x: 156, dest_y: 150})
    assert_eventually(fn -> get_player_state(guest.pid).x == 156 end)
    refute StatusStorage.has_status?(:player, guest.character.id, :sc_drumbattle)
    simulate_incoming_message(guest.pid, %MoveRequest{dest_x: 153, dest_y: 150})

    assert_eventually(fn ->
      StatusStorage.has_status?(:player, guest.character.id, :sc_drumbattle)
    end)
  end

  for end_reason <- [:adaptation, :death, :warp, :logout, :exhaustion] do
    test "partner #{end_reason} ends the field and releases both performers" do
      %{bard: bard, dancer: dancer, guest: guest} = start_party(309, 5, 5)
      cast(bard, 309, 5)

      assert_eventually(fn ->
        StatusStorage.has_status?(:player, guest.character.id, :sc_drumbattle)
      end)

      assert_eventually(fn ->
        StatusStorage.has_status?(:player, dancer.character.id, :sc_dancing)
      end)

      case unquote(end_reason) do
        :adaptation ->
          cast(dancer, 304, 1)

        :death ->
          PlayerSession.apply_damage(dancer.pid, 50_000, nil)

        :warp ->
          PlayerSession.warp(dancer.pid, @map, 170, 170)

        :logout ->
          end_player_session(dancer)

        :exhaustion ->
          PlayerSession.set_vitals(dancer.pid, sp: 0)
          assert_eventually(fn -> get_player_state(dancer.pid).stats.current_state.sp == 0 end)

          StatusStorage.update_status(:player, dancer.character.id, :sc_dancing, fn status ->
            %{
              status
              | next_tick_at: System.monotonic_time(:millisecond) - 1,
                state: %{status.state | ticks: 2}
            }
          end)

          StatusTickManager.force_tick()
      end

      assert_eventually(fn -> Storage.get_groups_by_caster(:player, bard.character.id) == [] end)
      refute StatusStorage.has_status?(:player, bard.character.id, :sc_dancing)
      refute StatusStorage.has_status?(:player, dancer.character.id, :sc_dancing)
      refute StatusStorage.has_status?(:player, guest.character.id, :sc_drumbattle)
    end
  end

  test "Mental Sensing marks monsters, not players, and removes the mark on exit" do
    %{bard: bard, guest: guest} = start_party(307, 5, 5)

    mob =
      start_mob_session(
        unit_id: System.unique_integer([:positive]),
        map_name: @map,
        position: {152, 150},
        vit: 0,
        luk: 0
      )

    cast(bard, 307, 5)
    assert_eventually(fn -> StatusStorage.has_status?(:mob, mob.unit_id, :sc_richmankim) end)
    assert %{val1: 5} = StatusStorage.get_status(:mob, mob.unit_id, :sc_richmankim)
    refute StatusStorage.has_status?(:player, guest.character.id, :sc_richmankim)
    MobSession.warp(mob.pid, @map, 160, 160)
    assert_eventually(fn -> not StatusStorage.has_status?(:mob, mob.unit_id, :sc_richmankim) end)
  end

  test "both performers pay Drum upkeep, not just its initiating caster" do
    %{bard: bard, dancer: dancer} = start_party(309, 5, 5)
    cast(bard, 309, 5)

    for performer <- [bard, dancer] do
      id = performer.character.id
      assert_eventually(fn -> StatusStorage.has_status?(:player, id, :sc_dancing) end)
      PlayerSession.set_vitals(performer.pid, sp: 10)
      assert_eventually(fn -> get_player_state(performer.pid).stats.current_state.sp == 10 end)

      :ok =
        StatusStorage.update_status(:player, id, :sc_dancing, fn status ->
          %{
            status
            | next_tick_at: System.monotonic_time(:millisecond) - 1,
              state: %{status.state | ticks: 2}
          }
        end)

      StatusTickManager.force_tick()
      assert_eventually(fn -> get_player_state(performer.pid).stats.current_state.sp == 9 end)
    end
  end

  test "Roki blocks allied players and mobs, but leaves its performers able to stop" do
    %{bard: bard, dancer: dancer, guest: guest} = start_party(311, 1, 1)

    mob =
      start_mob_session(
        unit_id: System.unique_integer([:positive]),
        map_name: @map,
        position: {152, 150},
        vit: 0,
        luk: 0
      )

    cast(bard, 311, 1)

    assert_eventually(fn ->
      StatusStorage.has_status?(:player, guest.character.id, :sc_rokisweil)
    end)

    assert_eventually(fn -> StatusStorage.has_status?(:mob, mob.unit_id, :sc_rokisweil) end)
    refute StatusStorage.has_status?(:player, bard.character.id, :sc_rokisweil)
    refute StatusStorage.has_status?(:player, dancer.character.id, :sc_rokisweil)
    cast(dancer, 304, 1)
    assert_eventually(fn -> Storage.get_groups_by_caster(:player, bard.character.id) == [] end)
  end

  test "Lullaby sleeps enemies periodically and its sleep outlasts the field" do
    %{bard: bard, dancer: dancer, guest: guest} = start_party(306, 1, 1)

    mob =
      start_mob_session(
        unit_id: System.unique_integer([:positive]),
        map_name: @map,
        position: {152, 150},
        vit: 0,
        luk: 0
      )

    cast(bard, 306, 1)
    assert_eventually(fn -> StatusStorage.has_status?(:mob, mob.unit_id, :sc_sleep) end)
    refute StatusStorage.has_status?(:player, guest.character.id, :sc_sleep)
    refute StatusStorage.has_status?(:player, bard.character.id, :sc_sleep)
    refute StatusStorage.has_status?(:player, dancer.character.id, :sc_sleep)

    StatusInterpreter.remove_status(:mob, mob.unit_id, :sc_sleep)
    assert_eventually(fn -> StatusStorage.has_status?(:mob, mob.unit_id, :sc_sleep) end, 8_000)
    [group] = Storage.get_groups_by_caster(:player, bard.character.id)
    SkillUnit.destroy(group.group_id)
    assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_sleep)
  end

  defp start_party(skill_id, bard_level, dancer_level) do
    bard = character(:bard, {150, 150}, %{skill_id => bard_level, 304 => 1})
    dancer = character(:dancer, {151, 150}, %{skill_id => dancer_level, 304 => 1})
    guest = character(:novice, {153, 150}, %{})
    {:ok, party} = PartyManager.create("Ensemble#{bard.id}", bard)

    for member <- [dancer, guest] do
      {:ok, _} = PartyManager.add_member(party.party_id, member)
    end

    %{bard: start_session(bard), dancer: start_session(dancer), guest: start_session(guest)}
  end

  defp character(job, {x, y}, skills) do
    unique = System.unique_integer([:positive])
    userid = "ensfield#{unique}"
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
        name: "#{job}#{unique}",
        class: %{bard: 19, dancer: 20, novice: 0}[job],
        sex: sex,
        base_level: 99,
        job_level: 50,
        vit: 0,
        luk: 0,
        int: 500,
        dex: 10,
        agi: 10,
        hp: 500,
        max_hp: 500,
        sp: 500,
        max_sp: 500,
        learned_skills:
          Map.new(Map.put(skills, 1, 9), fn {id, level} -> {Integer.to_string(id), level} end),
        last_map: @map,
        last_x: x,
        last_y: y,
        save_map: @map,
        save_x: x,
        save_y: y
      }
      |> Character.new()
      |> Repo.insert()

    if job in [:bard, :dancer] do
      {:ok, _} =
        InventoryPersistence.insert_item(character.id, %{
          nameid: if(job == :bard, do: 1901, else: 1960),
          amount: 1,
          identify: 1,
          equip: 2
        })
    end

    character
  end

  defp start_session(character) do
    session =
      start_player_session(
        character: Repo.get!(Character, character.id),
        map_name: @map,
        position: {character.last_x, character.last_y}
      )

    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp cast(session, skill_id, level) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: session.character.id
    })
  end
end
