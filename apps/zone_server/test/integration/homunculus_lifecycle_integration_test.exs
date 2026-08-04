defmodule Aesir.ZoneServer.Integration.HomunculusLifecycleIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus

  alias Aesir.Net.HomunculusDeleteCommand
  alias Aesir.Net.HomunculusFeedCommand
  alias Aesir.Net.HomunculusPrivateState
  alias Aesir.Net.HomunculusRequest
  alias Aesir.Net.HomunculusRestCommand
  alias Aesir.Net.HomunculusResult
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillEffect

  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @map "hom_lifecycle_e2e"
  @embryo 7_142
  @seed 7_140
  @pet_food 537
  @call 243
  @rest 244
  @resurrection 247

  setup :verify_on_exit!
  setup {Aesir.MimicMode, :global}

  setup do
    Mimic.copy(Persistence)
    put_map(@map)

    previous = Application.get_env(:zone_server, :homunculus_initial_selector)
    Application.put_env(:zone_server, :homunculus_initial_selector, fn 8 -> 1 end)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:zone_server, :homunculus_initial_selector, previous),
        else: Application.delete_env(:zone_server, :homunculus_initial_selector)
    end)

    :ok
  end

  test "one owner journey creates, rests, recalls, dies, resurrects, reconnects, and deletes" do
    character = character_fixture()
    seed_item(character.id, @embryo)
    seed_item(character.id, @seed)
    seed_item(character.id, @pet_food)
    first = start(character)

    cast(first.pid, @call, 1)
    assert_receive {:packet_sent, %SkillEffect{skill_id: @call}, _}, 1_000

    active = eventually_state(first.pid, & &1.homunculus)
    durable_id = active.homunculus.id
    first_gid = active.homunculus.world_gid
    assert Inventory.held_amount(active.game_state.inventory, @embryo) == 0
    assert_one_world_unit(first.pid, first_gid)

    request(first.pid, 10, {:rest, %HomunculusRestCommand{}})
    rested = assert_result(10)
    assert rested.lifecycle == :HOMUNCULUS_LIFECYCLE_RESTED
    assert PlayerSession.get_state(first.pid).homunculus.world_gid == nil

    assert Inventory.held_amount(PlayerSession.get_state(first.pid).game_state.inventory, @seed) ==
             1

    cast(first.pid, @call, 1)
    assert_receive {:packet_sent, %SkillEffect{skill_id: @call}, _}, 1_000
    recalled = eventually_state(first.pid, &(&1.homunculus.lifecycle == :active && &1))
    assert Inventory.held_amount(recalled.game_state.inventory, @seed) == 0
    assert recalled.homunculus.id == durable_id
    assert_one_world_unit(first.pid, recalled.homunculus.world_gid)
    flush_packets()

    request(first.pid, 12, {:feed, %HomunculusFeedCommand{}})
    fed = assert_result(12)
    assert fed.hunger == recalled.homunculus.hunger + 10
    assert fed.intimacy_hundredths == recalled.homunculus.intimacy_hundredths + 75

    assert fed.durable_id == durable_id

    assert Inventory.held_amount(
             PlayerSession.get_state(first.pid).game_state.inventory,
             @pet_food
           ) == 0

    fed_row = Repo.get_by!(Homunculus, character_id: character.id)
    assert fed_row.hunger == fed.hunger
    assert fed_row.intimacy_hundredths == fed.intimacy_hundredths

    assert :ok =
             DamageApplication.apply_unit_damage(
               :homunculus,
               first.pid,
               recalled.homunculus.world_gid,
               recalled.homunculus.hp,
               %{skill_id: 0},
               nil
             )

    dead = eventually_state(first.pid, &(&1.homunculus.lifecycle == :dead && &1))
    assert dead.homunculus.world_gid == nil
    assert Repo.get_by!(Homunculus, character_id: character.id).lifecycle == "dead"

    cast(first.pid, @resurrection, 5)
    casting = eventually_state(first.pid, & &1.game_state.casting)
    send(first.pid, {:skill, {:cast_complete, casting.game_state.casting.token}})
    revived = eventually_state(first.pid, &(&1.homunculus.lifecycle == :active && &1))
    resurrection_deadline = revived.game_state.skill_cooldowns[@resurrection]
    assert resurrection_deadline > System.monotonic_time(:millisecond)
    assert_receive {:packet_sent, %SkillEffect{skill_id: @resurrection}, _}, 1_000

    :ok = PlayerSession.disconnect(first.pid)
    reloaded = character |> Repo.reload!() |> Repo.preload(:homunculus)
    durable_cooldown = reloaded.homunculus.cooldowns["247"]
    second = start(reloaded)
    restored = eventually_state(second.pid, & &1.homunculus)
    assert restored.homunculus.id == durable_id
    assert restored.homunculus.hunger == fed.hunger
    assert restored.homunculus.intimacy_hundredths == fed.intimacy_hundredths
    assert Inventory.held_amount(restored.game_state.inventory, @pet_food) == 0

    assert restored.game_state.skill_cooldowns[@resurrection] >
             System.monotonic_time(:millisecond)

    assert restored.game_state.skill_cooldowns[@resurrection] -
             System.monotonic_time(:millisecond) <=
             durable_cooldown

    assert_one_world_unit(second.pid, restored.homunculus.world_gid)

    request(second.pid, 11, {:delete, %HomunculusDeleteCommand{confirmed: true}})

    assert_receive {:packet_sent, %HomunculusResult{request_id: 11, success: true, state: nil},
                    _},
                   1_000

    assert Repo.get_by(Homunculus, character_id: character.id) == nil
    assert PlayerSession.get_state(second.pid).homunculus == nil
    assert UnitRegistry.count_units_by_type(:homunculus) == 0
  end

  test "Rest cooldown survives an immediate disconnect and reconnect" do
    character = character_fixture()
    insert_homunculus(character.id)
    first = start(Repo.preload(character, :homunculus))

    request(first.pid, 14, {:rest, %HomunculusRestCommand{}})
    assert_result(14)

    before_disconnect = PlayerSession.get_state(first.pid)
    cooldown_deadline = before_disconnect.game_state.skill_cooldowns[@rest]
    assert cooldown_deadline > System.monotonic_time(:millisecond)
    assert before_disconnect.homunculus.cooldowns[@rest] == cooldown_deadline

    :ok = PlayerSession.disconnect(first.pid)
    durable_remaining = Repo.get_by!(Homunculus, character_id: character.id).cooldowns["244"]
    assert durable_remaining > 0
    assert durable_remaining <= 20_000

    second = start(character |> Repo.reload!() |> Repo.preload(:homunculus))
    restored = eventually_state(second.pid, & &1.homunculus)
    restored_deadline = restored.game_state.skill_cooldowns[@rest]
    restored_remaining = restored_deadline - System.monotonic_time(:millisecond)

    assert restored.homunculus.cooldowns[@rest] == restored_deadline
    assert restored_remaining > 0
    assert restored_remaining <= durable_remaining
  end

  test "confirmed deletion cancels an in-flight Resurrection without settlement" do
    character = character_fixture()
    insert_dead_homunculus(character.id)
    session = start(Repo.preload(character, :homunculus))
    before_sp = PlayerSession.get_state(session.pid).game_state.stats.current_state.sp

    cast(session.pid, @resurrection, 5)
    casting = eventually_state(session.pid, & &1.game_state.casting)
    token = casting.game_state.casting.token

    request(session.pid, 13, {:delete, %HomunculusDeleteCommand{confirmed: true}})

    assert_receive {:packet_sent, %HomunculusResult{request_id: 13, success: true, state: nil},
                    _},
                   1_000

    send(session.pid, {:skill, {:cast_complete, token}})

    refute_receive {:packet_sent, %SkillEffect{skill_id: @resurrection}, _}, 100
    refute_receive {:packet_sent, %HomunculusPrivateState{}, _}, 100
    assert Repo.get_by(Homunculus, character_id: character.id) == nil
    assert PlayerSession.get_state(session.pid).homunculus == nil
    assert PlayerSession.get_state(session.pid).game_state.stats.current_state.sp == before_sp
    assert PlayerSession.get_state(session.pid).game_state.skill_cooldowns[@resurrection] == nil
    assert UnitRegistry.count_units_by_type(:homunculus) == 0
  end

  test "abrupt owner death reconnect removes registry and spatial ghosts before one restore" do
    character = character_fixture()
    insert_homunculus(character.id)
    first = start(Repo.preload(character, :homunculus))
    old = PlayerSession.get_state(first.pid).homunculus

    Process.unlink(first.pid)
    monitor = Process.monitor(first.pid)
    Process.exit(first.pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, _, :killed}, 1_000

    assert {:ok, {HomunculusState, _, dead_pid}} =
             UnitRegistry.get_unit(:homunculus, old.world_gid)

    refute Process.alive?(dead_pid)
    assert {:ok, {_, _, @map}} = SpatialIndex.get_unit_position(:homunculus, old.world_gid)

    second = start(character |> Repo.reload!() |> Repo.preload(:homunculus))
    restored = eventually_state(second.pid, & &1.homunculus).homunculus
    assert restored.id == old.id
    assert UnitRegistry.count_units_by_type(:homunculus) == 1
    assert {:error, :not_found} = UnitRegistry.get_unit(:homunculus, old.world_gid)
    assert {:error, :not_found} = SpatialIndex.get_unit_position(:homunculus, old.world_gid)
    assert_one_world_unit(second.pid, restored.world_gid)
  end

  test "failed create transaction survives reconnect without consuming or publishing success" do
    character = character_fixture()
    seed_item(character.id, @embryo)
    first = start(character)

    expect(Persistence, :create_with_item, fn _, _, _, _ ->
      {:error, {:homunculus, :forced_create_failure}}
    end)

    cast(first.pid, @call, 1)
    Process.sleep(100)
    refute_receive {:packet_sent, %SkillEffect{skill_id: @call}, _}, 50
    assert PlayerSession.get_state(first.pid).homunculus == nil
    :ok = PlayerSession.disconnect(first.pid)

    second = start(character |> Repo.reload!() |> Repo.preload(:homunculus))
    state = PlayerSession.get_state(second.pid)
    assert state.homunculus == nil
    assert Inventory.held_amount(state.game_state.inventory, @embryo) == 1
    assert state.game_state.skill_cooldowns[@call] == nil
    assert Repo.get_by(Homunculus, character_id: character.id) == nil
    assert UnitRegistry.count_units_by_type(:homunculus) == 0
  end

  test "failed delete transaction survives reconnect with the same companion and world presence" do
    character = character_fixture()
    row = insert_homunculus(character.id)
    first = start(Repo.preload(character, :homunculus))

    expect(Persistence, :delete, fn _, _ -> {:error, {:homunculus, :forced_delete_failure}} end)
    request(first.pid, 30, {:delete, %HomunculusDeleteCommand{confirmed: true}})

    assert_receive {:packet_sent, %HomunculusResult{request_id: 30, success: false, state: state},
                    _},
                   1_000

    assert state.durable_id == row.id
    refute state.lifecycle == :HOMUNCULUS_LIFECYCLE_UNSPECIFIED
    assert PlayerSession.get_state(first.pid).homunculus.id == row.id
    :ok = PlayerSession.disconnect(first.pid)

    second = start(character |> Repo.reload!() |> Repo.preload(:homunculus))
    restored = PlayerSession.get_state(second.pid).homunculus
    assert restored.id == row.id
    assert Repo.get_by!(Homunculus, character_id: character.id).id == row.id
    assert_one_world_unit(second.pid, restored.world_gid)
  end

  defp start(character) do
    session = start_player_session(character: character, map_name: @map, position: {50, 50})
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    flush_packets()
    session
  end

  defp request(pid, request_id, command) do
    simulate_incoming_message(pid, %HomunculusRequest{request_id: request_id, command: command})
  end

  defp assert_result(request_id) do
    assert_receive {:packet_sent,
                    %HomunculusResult{request_id: ^request_id, success: true, state: state}, _},
                   1_000

    state
  end

  defp cast(pid, skill_id, level) do
    target_id = PlayerSession.get_state(pid).game_state.character_id

    simulate_incoming_message(pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id
    })
  end

  defp eventually_state(pid, predicate) do
    assert_eventually(fn ->
      state = PlayerSession.get_state(pid)
      predicate.(state)
    end)

    PlayerSession.get_state(pid)
  end

  defp assert_one_world_unit(pid, gid) do
    assert UnitRegistry.count_units_by_type(:homunculus) == 1

    assert {:ok, {HomunculusState, %{world_gid: ^gid}, ^pid}} =
             UnitRegistry.get_unit(:homunculus, gid)

    assert {:ok, {_, _, @map}} = SpatialIndex.get_unit_position(:homunculus, gid)
  end

  defp character_fixture do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "home2e#{suffix}",
        user_pass: "password",
        email: "home2e#{suffix}@example.com"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "HomE2E#{suffix}",
      class: 18,
      base_level: 50,
      job_level: 50,
      hp: 5_000,
      max_hp: 5_000,
      sp: 500,
      max_sp: 500,
      learned_skills: %{"238" => 1, "243" => 1, "244" => 1, "247" => 5},
      last_map: @map,
      last_x: 50,
      last_y: 50
    })
    |> Repo.insert!()
  end

  defp insert_homunculus(character_id) do
    %Homunculus{}
    |> Homunculus.changeset(%{
      character_id: character_id,
      class_id: 6_001,
      name: "Lif",
      lifecycle: "active",
      level: 50,
      hp: 1_000,
      max_hp: 1_000,
      sp: 200,
      max_sp: 200,
      active_remaining_ms: 1_800_000,
      learned_skills: %{"8001" => 1}
    })
    |> Repo.insert!()
  end

  defp insert_dead_homunculus(character_id) do
    %Homunculus{}
    |> Homunculus.changeset(%{
      character_id: character_id,
      class_id: 6_001,
      name: "Lif",
      lifecycle: "dead",
      level: 50,
      hp: 0,
      max_hp: 1_000,
      sp: 200,
      max_sp: 200,
      active_remaining_ms: 0,
      learned_skills: %{"8001" => 1}
    })
    |> Repo.insert!()
  end

  defp seed_item(character_id, nameid) do
    {:ok, _} =
      InventoryPersistence.insert_item(character_id, %{nameid: nameid, amount: 1, identify: 1})
  end

  defp put_map(name) do
    :ets.insert(EtsTable.table_for(:map_cache), {name, MapData.new(name, 100, 100)})
  end
end
