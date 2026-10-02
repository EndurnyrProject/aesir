defmodule Aesir.ZoneServer.Integration.PreRePerformanceLifecycleIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log
  @moduletag game_mode: :pre_renewal, integration_re: false

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence

  @origin {150, 150}
  @whistle 319
  @adaptation 304
  @encore 305
  @violin 1901

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", MapData.new("prontera", 200, 200)})
    bard = start_character("Bard", bard?: true, position: @origin)
    listener = start_character("Listener", position: {155, 150})
    %{bard: bard, listener: listener}
  end

  test "Whistle places a 49-cell field and locks the performer without buffing them", %{
    bard: bard
  } do
    cast(bard, @whistle, 5)
    bard_id = bard.character.id
    assert_eventually(fn -> match?([_], Storage.get_groups_by_caster(:player, bard_id)) end)
    [group] = Storage.get_groups_by_caster(:player, bard_id)
    assert group.center == @origin
    assert length(group.cells) == 49

    assert %{val1: @whistle, val2: group_id} =
             StatusStorage.get_status(:player, bard_id, :sc_dancing)

    assert group_id == group.group_id
    refute StatusStorage.has_status?(:player, bard_id, :sc_whistle)
  end

  test "entering grants the song, leaving starts a 20-second linger, and re-entry restores it", %{
    bard: bard,
    listener: listener
  } do
    cast(bard, @whistle, 5)

    assert_eventually(fn ->
      match?([_], Storage.get_groups_by_caster(:player, bard.character.id))
    end)

    move(listener, {152, 150})
    assert_eventually(fn -> position(listener) == {152, 150} end)

    assert_eventually(fn ->
      match?(
        %{expires_at: nil, state: %{field_support: true}},
        StatusStorage.get_status(:player, listener.character.id, :sc_whistle)
      )
    end)

    move(listener, {155, 150})
    assert_eventually(fn -> position(listener) == {155, 150} end)

    assert_eventually(fn ->
      case StatusStorage.get_status(:player, listener.character.id, :sc_whistle) do
        %{expires_at: expires_at, state: state} when is_integer(expires_at) ->
          not Map.get(state, :field_support, false) and
            (expires_at - System.monotonic_time(:millisecond)) in 1..20_000

        _ ->
          false
      end
    end)

    move(listener, {152, 150})
    assert_eventually(fn -> position(listener) == {152, 150} end)

    assert_eventually(fn ->
      match?(
        %{expires_at: nil, state: %{field_support: true}},
        StatusStorage.get_status(:player, listener.character.id, :sc_whistle)
      )
    end)
  end

  test "a walking performer is slowed and the field follows, moving its occupancy", %{
    bard: bard,
    listener: listener
  } do
    bard_id = bard.character.id
    listener_id = listener.character.id
    cast(bard, @whistle, 5)
    assert_eventually(fn -> StatusStorage.has_status?(:player, bard_id, :sc_dancing) end)
    assert_eventually(fn -> get_player_state(bard.pid).walk_speed == 900 end)
    refute StatusStorage.has_status?(:player, listener_id, :sc_whistle)

    move(bard, {152, 150})
    assert_eventually(fn -> position(bard) == {152, 150} end, 6_000)

    assert_eventually(fn ->
      match?([%{center: {152, 150}}], Storage.get_groups_by_caster(:player, bard_id))
    end)

    [group] = Storage.get_groups_by_caster(:player, bard_id)
    assert length(group.cells) == 49
    assert [] == Storage.get_groups_at_cell("prontera", 147, 150)
    assert [_] = Storage.get_groups_at_cell("prontera", 155, 150)

    assert_eventually(fn ->
      match?(
        %{state: %{field_support: true}},
        StatusStorage.get_status(:player, listener_id, :sc_whistle)
      )
    end)
  end

  test "the performer cannot attack or Encore, but may cast Musical Strike", %{bard: bard} do
    mob =
      start_mob_session(
        unit_id: System.unique_integer([:positive]),
        map_name: "prontera",
        position: {151, 150},
        hp: 50_000,
        max_hp: 50_000,
        awake: false
      )

    cast(bard, @whistle, 5)
    bard_id = bard.character.id
    assert_eventually(fn -> StatusStorage.has_status?(:player, bard_id, :sc_dancing) end)

    initial_hp = get_mob_state(mob.pid).hp
    simulate_incoming_message(bard.pid, %ActionRequest{target_id: mob.unit_id, action: 0})
    refute_eventually(fn -> get_mob_state(mob.pid).hp < initial_hp end, 350)

    before = get_player_state(bard.pid).stats.current_state.sp
    cast(bard, @encore)
    refute_eventually(fn -> get_player_state(bard.pid).stats.current_state.sp < before end, 350)
    assert StatusStorage.has_status?(:player, bard_id, :sc_dancing)

    cast(bard, 316, 1, mob.unit_id)
    assert_eventually(fn -> get_player_state(bard.pid).stats.current_state.sp < before end, 4_000)
  end

  test "Adaptation ends the field, lets its occupant linger, and Encore replays for half SP", %{
    bard: bard,
    listener: listener
  } do
    bard_id = bard.character.id
    listener_id = listener.character.id
    cast(bard, @whistle, 5)
    assert_eventually(fn -> StatusStorage.has_status?(:player, bard_id, :sc_dancing) end)
    move(listener, {152, 150})
    assert_eventually(fn -> StatusStorage.has_status?(:player, listener_id, :sc_whistle) end)

    cast(bard, @adaptation)
    assert_eventually(fn -> not StatusStorage.has_status?(:player, bard_id, :sc_dancing) end)
    assert_eventually(fn -> Storage.get_groups_by_caster(:player, bard_id) == [] end)

    assert_eventually(fn ->
      case StatusStorage.get_status(:player, listener_id, :sc_whistle) do
        %{expires_at: expires_at} when is_integer(expires_at) -> true
        _ -> false
      end
    end)

    before = get_player_state(bard.pid).stats.current_state.sp
    cast(bard, @encore)
    assert_eventually(fn -> match?([_], Storage.get_groups_by_caster(:player, bard_id)) end)
    assert_eventually(fn -> StatusStorage.has_status?(:player, bard_id, :sc_dancing) end)
    assert before - get_player_state(bard.pid).stats.current_state.sp == 20
  end

  test "upkeep charges on cadence and ends the field when the next payment fails", %{
    bard: bard,
    listener: listener
  } do
    bard_id = bard.character.id
    listener_id = listener.character.id
    cast(bard, @whistle, 5)
    assert_eventually(fn -> StatusStorage.has_status?(:player, bard_id, :sc_dancing) end)
    move(listener, {152, 150})
    assert_eventually(fn -> StatusStorage.has_status?(:player, listener_id, :sc_whistle) end)

    PlayerSession.set_vitals(bard.pid, sp: 2)
    assert_eventually(fn -> get_player_state(bard.pid).stats.current_state.sp == 2 end)

    for tick <- 1..4 do
      tick_dancing(bard_id, tick)
      assert get_player_state(bard.pid).stats.current_state.sp == 2
    end

    tick_dancing(bard_id, 5)
    assert_eventually(fn -> get_player_state(bard.pid).stats.current_state.sp == 1 end)
    for tick <- 6..9, do: tick_dancing(bard_id, tick)
    tick_dancing(bard_id, 10)
    assert_eventually(fn -> get_player_state(bard.pid).stats.current_state.sp == 0 end)
    assert StatusStorage.has_status?(:player, bard_id, :sc_dancing)
    for tick <- 11..14, do: tick_dancing(bard_id, tick)
    tick_dancing(bard_id, 15, :removed)

    assert_eventually(fn -> Storage.get_groups_by_caster(:player, bard_id) == [] end)

    assert_eventually(fn ->
      match?(
        %{expires_at: expires_at} when is_integer(expires_at),
        StatusStorage.get_status(:player, listener_id, :sc_whistle)
      )
    end)
  end

  test "death ends the performer lock and field", %{bard: bard, listener: listener} do
    bard_id = bard.character.id
    cast(bard, @whistle, 5)
    assert_eventually(fn -> StatusStorage.has_status?(:player, bard_id, :sc_dancing) end)
    occupy(listener)
    hp = get_player_state(bard.pid).stats.current_state.hp
    PlayerSession.apply_damage(bard.pid, hp, nil)
    assert_eventually(fn -> get_player_state(bard.pid).action_state == :dead end)
    assert_eventually(fn -> Storage.get_groups_by_caster(:player, bard_id) == [] end)
    refute StatusStorage.has_status?(:player, bard_id, :sc_dancing)
    assert_lingering(listener)
  end

  test "cross-map warp clears the lock and group", %{bard: bard, listener: listener} do
    {:ok, _} = start_per_test_map("geffen")
    bard_id = bard.character.id
    cast(bard, @whistle, 5)
    assert_eventually(fn -> StatusStorage.has_status?(:player, bard_id, :sc_dancing) end)
    occupy(listener)

    PlayerSession.warp(bard.pid, "geffen", 50, 50)
    assert_eventually(fn -> get_player_state(bard.pid).map_name == "geffen" end)
    assert_eventually(fn -> Storage.get_groups_by_caster(:player, bard_id) == [] end)
    refute StatusStorage.has_status?(:player, bard_id, :sc_dancing)
    assert_lingering(listener)
  end

  test "exactly a quarter MaxHP leaves the lock, but a larger hit ends it", %{
    bard: bard,
    listener: listener
  } do
    bard_id = bard.character.id
    cast(bard, @whistle, 5)
    assert_eventually(fn -> StatusStorage.has_status?(:player, bard_id, :sc_dancing) end)
    occupy(listener)
    max_hp = get_player_state(bard.pid).stats.derived_stats.max_hp
    quarter = div(max_hp, 4)
    hit = %{dmg_type: :physical, is_short: true, element: :neutral}

    assert :ok =
             DamageApplication.apply_unit_damage(:player, bard.pid, bard_id, quarter, hit, nil)

    assert StatusStorage.has_status?(:player, bard_id, :sc_dancing)

    assert :ok =
             DamageApplication.apply_unit_damage(
               :player,
               bard.pid,
               bard_id,
               quarter + 1,
               hit,
               nil
             )

    assert_eventually(fn -> not StatusStorage.has_status?(:player, bard_id, :sc_dancing) end)
    assert_eventually(fn -> Storage.get_groups_by_caster(:player, bard_id) == [] end)
    assert_lingering(listener)
  end

  defp occupy(listener) do
    move(listener, {152, 150})

    assert_eventually(fn ->
      match?(
        %{state: %{field_support: true}},
        StatusStorage.get_status(:player, listener.character.id, :sc_whistle)
      )
    end)
  end

  defp assert_lingering(listener) do
    assert_eventually(fn ->
      match?(
        %{expires_at: expires_at} when is_integer(expires_at),
        StatusStorage.get_status(:player, listener.character.id, :sc_whistle)
      )
    end)
  end

  defp tick_dancing(id, count, outcome \\ :active) do
    :ok =
      StatusStorage.update_status(:player, id, :sc_dancing, fn status ->
        %{status | next_tick_at: System.monotonic_time(:millisecond) - 1}
      end)

    StatusTickManager.force_tick()

    assert_eventually(fn ->
      case {outcome, StatusStorage.get_status(:player, id, :sc_dancing)} do
        {:active, %{state: %{ticks: ^count}}} -> true
        {:removed, nil} -> true
        _ -> false
      end
    end)
  end

  defp position(session) do
    state = get_player_state(session.pid)
    {state.x, state.y}
  end

  defp move(session, {x, y}) do
    simulate_incoming_message(session.pid, %MoveRequest{dest_x: x, dest_y: y})
  end

  defp cast(session, skill_id, level \\ 1, target_id \\ nil) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id || session.character.id
    })
  end

  defp start_character(label, opts) do
    unique = System.unique_integer([:positive])
    userid = "perf#{unique}"
    bard? = Keyword.get(opts, :bard?, false)
    {x, y} = Keyword.fetch!(opts, :position)

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "#{label}#{unique}",
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
          if(bard?, do: %{"319" => 5, "304" => 1, "305" => 1, "316" => 5}, else: %{"1" => 9}),
        last_map: "prontera",
        last_x: x,
        last_y: y,
        save_map: "prontera",
        save_x: x,
        save_y: y
      }
      |> Character.new()
      |> Repo.insert()

    if bard? do
      {:ok, _} =
        InventoryPersistence.insert_item(character.id, %{
          nameid: @violin,
          amount: 1,
          identify: 1,
          equip: 2
        })

      {:ok, _} =
        InventoryPersistence.insert_item(character.id, %{
          nameid: 1750,
          amount: 10,
          identify: 1,
          equip: 0x008000
        })
    end

    session = start_player_session(character: character, map_name: "prontera", position: {x, y})
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end
end
