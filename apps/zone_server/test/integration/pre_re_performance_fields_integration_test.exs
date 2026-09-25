defmodule Aesir.ZoneServer.Integration.PreRePerformanceFieldsIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log
  @moduletag game_mode: :pre_renewal, integration_re: false

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.Stats

  @map "prontera"
  @origin {150, 150}
  @violin 1901
  @whip 1960

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 200, 200)})
    :ok
  end

  test "Dissonance damages a nearby enemy mob every three seconds without hurting its Bard" do
    bard = start_performer(:bard, "Dissonance", @origin, %{"317" => 3, "315" => 10})

    mob =
      start_mob_session(
        unit_id: System.unique_integer([:positive]),
        map_name: @map,
        position: {152, 150},
        hp: 50_000,
        max_hp: 50_000,
        awake: false
      )

    initial_mob_hp = get_mob_state(mob.pid).hp
    initial_bard_hp = get_player_state(bard.pid).stats.current_state.hp

    cast(bard, 317, 3)

    assert_eventually(fn ->
      match?([_], Storage.get_groups_by_caster(:player, bard.character.id))
    end)

    assert_eventually(fn -> get_mob_state(mob.pid).hp < initial_mob_hp end, 4_000)
    after_first = get_mob_state(mob.pid).hp
    assert_eventually(fn -> get_mob_state(mob.pid).hp < after_first end, 5_000)
    after_second = get_mob_state(mob.pid).hp
    assert_eventually(fn -> get_mob_state(mob.pid).hp < after_second end, 5_000)
    assert get_player_state(bard.pid).stats.current_state.hp >= initial_bard_hp
  end

  test "Apple of Idun heals an occupant every six seconds but not the Bard" do
    bard = start_performer(:bard, "Idun", @origin, %{"322" => 5})
    guest = start_performer(:novice, "Guest", {152, 150}, %{})
    vit = Stats.get_effective_stat(get_player_state(bard.pid).stats, :vit)
    expected = 30 + 5 * 5 + div(vit, 2)

    PlayerSession.apply_damage(guest.pid, 250, nil)
    PlayerSession.apply_damage(bard.pid, 250, nil)
    assert_eventually(fn -> get_player_state(guest.pid).stats.current_state.hp == 250 end)
    assert_eventually(fn -> get_player_state(bard.pid).stats.current_state.hp == 250 end)
    damaged = get_player_state(guest.pid).stats.current_state.hp
    bard_damaged = get_player_state(bard.pid).stats.current_state.hp

    cast(bard, 322, 5)

    assert_eventually(fn ->
      StatusStorage.has_status?(:player, guest.character.id, :sc_appleidun)
    end)

    assert_eventually(
      fn -> get_player_state(guest.pid).stats.current_state.hp >= damaged + expected end,
      4_000
    )

    assert_eventually(
      fn -> get_player_state(guest.pid).stats.current_state.hp >= damaged + 2 * expected end,
      8_000
    )

    assert get_player_state(bard.pid).stats.current_state.hp < bard_damaged + expected
  end

  test "Slow Grace affects a mob and hostile player, but only the player lingers" do
    map = "field_pvp"
    :ets.insert(EtsTable.table_for(:map_cache), {map, MapData.new(map, 200, 200)})
    {:ok, _} = start_per_test_map(map)
    :ok = MapFlags.set_runtime(map, :pvp, true)

    dancer = start_performer(:dancer, "Slow", @origin, %{"328" => 5}, map: map)
    hostile = start_performer(:novice, "Hostile", {152, 150}, %{}, map: map, vit: 0, luk: 0)

    mob =
      start_mob_session(
        unit_id: System.unique_integer([:positive]),
        map_name: map,
        position: {151, 150},
        hp: 10_000,
        max_hp: 10_000,
        awake: false,
        vit: 0,
        luk: 0
      )

    cast(dancer, 328, 5)

    assert_eventually(fn ->
      match?([_], Storage.get_groups_by_caster(:player, dancer.character.id))
    end)

    [group] = Storage.get_groups_by_caster(:player, dancer.character.id)
    assert Field.field_support(group).target?.({:mob, mob.unit_id})
    assert_eventually(fn -> FieldSupport.supported?(:mob, mob.unit_id, :sc_dontforgetme) end)
    assert_eventually(fn -> StatusStorage.has_status?(:mob, mob.unit_id, :sc_dontforgetme) end)

    assert_eventually(fn ->
      StatusStorage.has_status?(:player, hostile.character.id, :sc_dontforgetme)
    end)

    MobSession.warp(mob.pid, map, 160, 160)
    assert_eventually(fn -> get_mob_state(mob.pid).x == 160 end)

    assert_eventually(fn ->
      not StatusStorage.has_status?(:mob, mob.unit_id, :sc_dontforgetme)
    end)

    move(hostile, {156, 150})
    assert_eventually(fn -> get_player_state(hostile.pid).x == 156 end)

    assert_eventually(fn ->
      match?(
        %{expires_at: expires_at} when is_integer(expires_at),
        StatusStorage.get_status(:player, hostile.character.id, :sc_dontforgetme)
      )
    end)
  end

  test "overlapping songs suppress field buffs, damage a mob, then restore the surviving song" do
    whistle = start_performer(:bard, "Whistle", @origin, %{"319" => 5, "304" => 1})
    bragi = start_performer(:bard, "Bragi", {154, 150}, %{"321" => 5, "304" => 1})
    guest = start_performer(:novice, "Crossing", {152, 150}, %{})

    mob =
      start_mob_session(
        unit_id: System.unique_integer([:positive]),
        map_name: @map,
        position: {152, 150},
        hp: 50_000,
        max_hp: 50_000,
        awake: false
      )

    guest_id = guest.character.id
    cast(whistle, 319, 5)
    assert_eventually(fn -> FieldSupport.field_owned?(:player, guest_id, :sc_whistle) end)
    before_mob_hp = get_mob_state(mob.pid).hp

    cast(bragi, 321, 5)

    assert_eventually(fn ->
      match?([_], Storage.get_groups_by_caster(:player, bragi.character.id))
    end)

    assert_eventually(fn -> not FieldSupport.field_owned?(:player, guest_id, :sc_whistle) end)
    assert_eventually(fn -> not FieldSupport.field_owned?(:player, guest_id, :sc_poembragi) end)
    assert_eventually(fn -> get_mob_state(mob.pid).hp < before_mob_hp end, 4_000)

    for status <- [:sc_whistle, :sc_poembragi] do
      if entry = StatusStorage.get_status(:player, guest_id, status) do
        assert is_integer(entry.expires_at)

        :ok =
          StatusStorage.update_status(:player, guest_id, status, fn current ->
            %{current | expires_at: System.monotonic_time(:millisecond) - 1}
          end)
      end
    end

    StatusTickManager.force_tick()

    assert_eventually(fn ->
      not StatusStorage.has_status?(:player, guest_id, :sc_whistle) and
        not StatusStorage.has_status?(:player, guest_id, :sc_poembragi)
    end)

    cast(bragi, 304, 1)
    assert_eventually(fn -> Storage.get_groups_by_caster(:player, bragi.character.id) == [] end)
    assert_eventually(fn -> FieldSupport.field_owned?(:player, guest_id, :sc_whistle) end, 2_000)
  end

  test "a song and dance share cells without suppressing either occupant buff" do
    bard = start_performer(:bard, "Song", @origin, %{"319" => 5})
    dancer = start_performer(:dancer, "Dance", {154, 150}, %{"327" => 5})
    guest = start_performer(:novice, "Shared", {152, 150}, %{})
    guest_id = guest.character.id

    cast(bard, 319, 5)
    cast(dancer, 327, 5)

    assert_eventually(fn ->
      match?([_], Storage.get_groups_by_caster(:player, bard.character.id))
    end)

    assert_eventually(fn ->
      match?([_], Storage.get_groups_by_caster(:player, dancer.character.id))
    end)

    assert_eventually(fn -> FieldSupport.field_owned?(:player, guest_id, :sc_whistle) end)
    assert_eventually(fn -> FieldSupport.field_owned?(:player, guest_id, :sc_humming) end)

    assert_eventually(fn ->
      groups =
        Storage.get_groups_by_caster(:player, bard.character.id) ++
          Storage.get_groups_by_caster(:player, dancer.character.id)

      length(groups) == 2 and
        Enum.all?(groups, &(MapSet.size(&1.state.performance.dissonant_cells) == 0))
    end)
  end

  defp cast(session, skill_id, level) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: session.character.id
    })
  end

  defp move(session, {x, y}) do
    simulate_incoming_message(session.pid, %MoveRequest{dest_x: x, dest_y: y})
  end

  defp start_performer(job, label, {x, y}, learned_skills, opts \\ []) do
    unique = System.unique_integer([:positive])
    userid = "field#{unique}"
    map = Keyword.get(opts, :map, @map)

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
        name: "#{label}#{unique}",
        class: %{bard: 19, dancer: 20, novice: 0}[job],
        sex: if(job == :dancer, do: "F", else: "M"),
        base_level: 99,
        job_level: 50,
        vit: Keyword.get(opts, :vit, 10),
        luk: Keyword.get(opts, :luk, 10),
        dex: 10,
        agi: 10,
        hp: 500,
        max_hp: 500,
        sp: 500,
        max_sp: 500,
        learned_skills: Map.merge(%{"1" => 9}, learned_skills),
        last_map: map,
        last_x: x,
        last_y: y,
        save_map: map,
        save_x: x,
        save_y: y
      }
      |> Character.new()
      |> Repo.insert()

    if job in [:bard, :dancer] do
      {:ok, _} =
        InventoryPersistence.insert_item(character.id, %{
          nameid: if(job == :bard, do: @violin, else: @whip),
          amount: 1,
          identify: 1,
          equip: 2
        })
    end

    session = start_player_session(character: character, map_name: map, position: {x, y})
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end
end
