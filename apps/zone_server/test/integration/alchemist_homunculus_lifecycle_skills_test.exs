defmodule Aesir.ZoneServer.Integration.AlchemistHomunculusLifecycleSkillsTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillEffect
  alias Aesir.Repo
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.LifecycleSkillHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence, as: HomunculusPersistence
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @moduletag :integration
  @map "prontera"
  @alchemist_class 18
  @call 243
  @rest 244
  @resurrection 247
  @embryo 7142
  @seed 7140

  setup :verify_on_exit!
  setup {Aesir.MimicMode, :global}

  setup do
    Mimic.copy(HomunculusPersistence)
    Mimic.copy(StateCommit)
    previous = Application.get_env(:zone_server, :homunculus_initial_selector)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:zone_server, :homunculus_initial_selector, previous),
        else: Application.delete_env(:zone_server, :homunculus_initial_selector)
    end)

    :ok
  end

  test "first Call consumes one Embryo, ten SP, and can select every initial variant" do
    for selection <- 1..8 do
      Application.put_env(:zone_server, :homunculus_initial_selector, fn 8 -> selection end)
      session = start_alchemist(@embryo)
      before = PlayerSession.get_state(session.pid)

      cast(session.pid, @call, 1)

      assert_eventually(fn ->
        state = PlayerSession.get_state(session.pid)
        state.homunculus && state.homunculus.class_id == 6000 + selection
      end)

      state = PlayerSession.get_state(session.pid)

      assert state.game_state.stats.current_state.sp ==
               before.game_state.stats.current_state.sp - 10

      assert Inventory.held_amount(state.game_state.inventory, @embryo) == 0
      assert state.homunculus.lifecycle == :active
      assert state.homunculus.hp == state.homunculus.max_hp
      assert state.homunculus.combat_stats.atk > 0
      assert state.homunculus.combat_stats.hit > 0
      assert is_integer(state.homunculus.world_gid)
      session_pid = session.pid

      assert {:ok, {HomunculusState, _, ^session_pid}} =
               UnitRegistry.get_unit(:homunculus, state.homunculus.world_gid)

      assert %Homunculus{class_id: class_id} =
               Repo.get_by(Homunculus, character_id: state.game_state.character_id)

      assert class_id == 6000 + selection
      end_player_session(session)
    end
  end

  test "missing item and failed transaction leave first Call entirely unchanged" do
    missing = start_alchemist(nil)
    missing_before = PlayerSession.get_state(missing.pid)
    cast(missing.pid, @call, 1)
    Process.sleep(100)
    assert PlayerSession.get_state(missing.pid) == missing_before
    end_player_session(missing)

    failed = start_alchemist(@embryo)
    failed_before = PlayerSession.get_state(failed.pid)

    Mimic.expect(HomunculusPersistence, :create_with_item, fn _, _, _, _ ->
      {:error, {:homunculus, :forced}}
    end)

    cast(failed.pid, @call, 1)
    Process.sleep(100)

    failed_after = PlayerSession.get_state(failed.pid)
    assert failed_after.game_state.inventory == failed_before.game_state.inventory

    assert failed_after.game_state.stats.current_state.sp ==
             failed_before.game_state.stats.current_state.sp

    assert failed_after.game_state.skill_cooldowns == failed_before.game_state.skill_cooldowns
    assert failed_after.homunculus == nil
    assert Repo.get_by(Homunculus, character_id: failed_after.game_state.character_id) == nil
    end_player_session(failed)
  end

  test "activation reservation failures do not settle Call" do
    for reason <- [:exhausted, :duplicate_session] do
      session = start_alchemist(@embryo)
      before = PlayerSession.get_state(session.pid)
      row_before = Repo.get_by(Homunculus, character_id: before.game_state.character_id)

      Mimic.expect(StateCommit, :reserve_activation, fn _session, _homunculus ->
        {:error, reason}
      end)

      clear_packet_inbox()
      cast(session.pid, @call, 1)
      after_state = PlayerSession.get_state(session.pid)

      assert_lifecycle_unchanged(after_state, before, row_before)
      assert Inventory.held_amount(after_state.game_state.inventory, @embryo) == 1
      refute_packet_sent(SkillEffect)
      refute_packet_sent(ItemRemoved)
      end_player_session(session)
    end
  end

  test "failed Resurrection reservation does not update its row or charge SP and cooldown" do
    session = start_alchemist(nil, nil, insert_homunculus: :dead)
    before = PlayerSession.get_state(session.pid)
    row_before = Repo.get_by(Homunculus, character_id: before.game_state.character_id)

    Mimic.expect(StateCommit, :reserve_activation, fn _session, _homunculus ->
      {:error, :exhausted}
    end)

    cast(session.pid, @resurrection, 1)
    casting = eventually_state(session.pid, & &1.game_state.casting)
    clear_packet_inbox()
    send(session.pid, {:skill, {:cast_complete, casting.game_state.casting.token}})
    after_state = PlayerSession.get_state(session.pid)

    assert_lifecycle_unchanged(after_state, before, row_before)
    refute_packet_sent(SkillEffect)
    refute_packet_sent(ItemRemoved)
    end_player_session(session)
  end

  test "failed persistence releases the reserved Homunculus GID" do
    session = start_alchemist(@embryo)
    gid = 1_900_001

    Mimic.expect(StateCommit, :reserve_activation, fn _session, _homunculus ->
      assert UnitRegistry.claim_unit_id(gid, :homunculus)
      {:ok, gid}
    end)

    Mimic.expect(HomunculusPersistence, :create_with_item, fn _, _, _, _ ->
      {:error, {:homunculus, :forced}}
    end)

    cast(session.pid, @call, 1)
    PlayerSession.get_state(session.pid)

    refute UnitRegistry.unit_id_exists?(gid)
    assert UnitRegistry.claim_unit_id(gid, :homunculus)
    UnitRegistry.release_unit_id(gid, :homunculus)
    end_player_session(session)
  end

  test "successful Call consumes exactly its reserved typed GID" do
    session = start_alchemist(@embryo)
    gid = 1_900_002

    Mimic.expect(StateCommit, :reserve_activation, fn _session, _homunculus ->
      assert UnitRegistry.claim_unit_id(gid, :homunculus)
      {:ok, gid}
    end)

    cast(session.pid, @call, 1)
    state = eventually_state(session.pid, & &1.homunculus)
    session_pid = session.pid

    assert state.homunculus.world_gid == gid

    assert {:ok, {HomunculusState, %{world_gid: ^gid}, ^session_pid}} =
             UnitRegistry.get_unit(:homunculus, gid)

    end_player_session(session)
  end

  test "Call commit survives a dead connection before packet delivery" do
    session = start_alchemist(@embryo)
    dead_connection = spawn(fn -> receive do: (:stop -> :ok) end)
    ref = Process.monitor(dead_connection)
    send(dead_connection, :stop)
    assert_receive {:DOWN, ^ref, :process, ^dead_connection, :normal}

    :sys.replace_state(session.pid, &%{&1 | connection_pid: dead_connection})
    cast(session.pid, @call, 1)
    state = eventually_state(session.pid, & &1.homunculus)

    assert Process.alive?(session.pid)
    assert state.homunculus.lifecycle == :active

    assert {:ok, {_module, _homunculus, session_pid}} =
             UnitRegistry.get_unit(:homunculus, state.homunculus.world_gid)

    assert session_pid == session.pid

    assert %Homunculus{lifecycle: "active"} =
             Repo.get_by(Homunculus, character_id: state.game_state.character_id)

    refute Enum.any?(
             InventoryPersistence.load_inventory(state.game_state.character_id),
             &(&1.nameid == @embryo)
           )

    end_player_session(session)
  end

  test "Rest below eighty percent HP leaves the aggregate unchanged" do
    session = active_session()

    :sys.replace_state(session.pid, fn state ->
      hp = div(state.homunculus.max_hp * 79, 100)
      StateCommit.commit(state, %{state.homunculus | hp: hp})
    end)

    assert_real_flow_rejected(session, @rest, 1)
    end_player_session(session)
  end

  test "Call while active leaves the aggregate unchanged" do
    session = active_session()
    assert_real_flow_rejected(session, @call, 1)
    end_player_session(session)
  end

  test "timed Resurrection rejects a replaced companion through its expected id" do
    session = start_alchemist(nil, nil, insert_homunculus: :dead)
    cast(session.pid, @resurrection, 1)
    casting = eventually_state(session.pid, & &1.game_state.casting)
    token = casting.game_state.casting.token

    :sys.replace_state(session.pid, fn state ->
      %{state | homunculus: %{state.homunculus | id: state.homunculus.id + 1}}
    end)

    before = PlayerSession.get_state(session.pid)
    row_before = Repo.get_by(Homunculus, character_id: before.game_state.character_id)
    clear_packet_inbox()
    send(session.pid, {:skill, {:cast_complete, token}})
    after_state = PlayerSession.get_state(session.pid)

    assert_lifecycle_unchanged(after_state, before, row_before)
    refute_packet_sent(SkillEffect)
    refute_packet_sent(ItemRemoved)
    end_player_session(session)
  end

  test "timed Resurrection rechecks SP at completion without settling" do
    session = start_alchemist(nil, nil, insert_homunculus: :dead)
    cast(session.pid, @resurrection, 1)
    casting = eventually_state(session.pid, & &1.game_state.casting)
    token = casting.game_state.casting.token

    :sys.replace_state(session.pid, fn state ->
      put_in(state.game_state.stats.current_state.sp, 0)
    end)

    before = PlayerSession.get_state(session.pid)
    row_before = Repo.get_by(Homunculus, character_id: before.game_state.character_id)
    clear_packet_inbox()
    send(session.pid, {:skill, {:cast_complete, token}})
    after_state = PlayerSession.get_state(session.pid)

    assert_lifecycle_unchanged(after_state, before, row_before)
    refute_packet_sent(SkillEffect)
    refute_packet_sent(ItemRemoved)
    end_player_session(session)
  end

  test "Rest cooldown rejection leaves the aggregate unchanged" do
    session = active_session()

    :sys.replace_state(session.pid, fn state ->
      cooldowns =
        Map.put(
          state.game_state.skill_cooldowns,
          @rest,
          System.monotonic_time(:millisecond) + 60_000
        )

      %{state | game_state: %{state.game_state | skill_cooldowns: cooldowns}}
    end)

    assert_real_flow_rejected(session, @rest, 1)
    end_player_session(session)
  end

  test "lifecycle settlement rejects an inventory changed by deferred charging" do
    session = start_alchemist(@embryo)
    state = PlayerSession.get_state(session.pid)
    {:ok, changed_inventory, _change} = remove_inventory_item(state.game_state.inventory, @embryo)
    charged = %{state.game_state | inventory: changed_inventory}

    assert {:error, :inventory_changed_before_lifecycle} =
             LifecycleSkillHandler.settle(state, charged, :call)

    assert Repo.get_by(Homunculus, character_id: state.game_state.character_id) == nil
    end_player_session(session)
  end

  test "Rest enforces the HP gate and recall consumes Seed of Life" do
    Application.put_env(:zone_server, :homunculus_initial_selector, fn 8 -> 1 end)
    session = start_alchemist(@embryo, @seed)
    cast(session.pid, @call, 1)
    assert_eventually(fn -> PlayerSession.get_state(session.pid).homunculus end)

    active = PlayerSession.get_state(session.pid)
    old_gid = active.homunculus.world_gid
    cast(session.pid, @rest, 1)

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus.lifecycle == :rested
    end)

    rested = PlayerSession.get_state(session.pid)

    assert rested.game_state.stats.current_state.sp ==
             active.game_state.stats.current_state.sp - 50

    assert {:error, :not_found} = UnitRegistry.get_unit(:homunculus, old_gid)

    cast(session.pid, @call, 1)

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus.lifecycle == :active
    end)

    recalled = PlayerSession.get_state(session.pid)
    assert Inventory.held_amount(recalled.game_state.inventory, @seed) == 0

    assert recalled.game_state.stats.current_state.sp ==
             rested.game_state.stats.current_state.sp - 10

    end_player_session(session)
  end

  test "every Resurrection rank settles only its matching timer with ranked HP, SP, and cooldown" do
    costs = [74, 68, 62, 56, 50]
    cooldowns = [140_000, 110_000, 80_000, 50_000, 20_000]

    for rank <- 1..5 do
      session = start_alchemist(nil, nil, insert_homunculus: :dead)
      before = PlayerSession.get_state(session.pid)
      cast(session.pid, @resurrection, rank)

      casting = eventually_state(session.pid, & &1.game_state.casting)
      assert casting.game_state.stats.current_state.sp == before.game_state.stats.current_state.sp
      token = casting.game_state.casting.token
      send(session.pid, {:skill, {:cast_complete, make_ref()}})
      Process.sleep(20)
      assert PlayerSession.get_state(session.pid).homunculus.lifecycle == :dead

      completed_at = System.monotonic_time(:millisecond)
      send(session.pid, {:skill, {:cast_complete, token}})

      assert_eventually(fn ->
        PlayerSession.get_state(session.pid).homunculus.lifecycle == :active
      end)

      revived = PlayerSession.get_state(session.pid)
      assert revived.homunculus.hp == 200 * rank

      assert revived.game_state.stats.current_state.sp ==
               before.game_state.stats.current_state.sp - Enum.at(costs, rank - 1)

      deadline = revived.game_state.skill_cooldowns[@resurrection]
      expected_cooldown = Enum.at(cooldowns, rank - 1)

      assert deadline in (completed_at + expected_cooldown - 100)..(completed_at +
                                                                      expected_cooldown + 100)

      end_player_session(session)
    end
  end

  defp active_session do
    session = start_alchemist(@embryo)
    cast(session.pid, @call, 1)
    eventually_state(session.pid, & &1.homunculus)
    clear_packet_inbox()
    session
  end

  defp assert_real_flow_rejected(session, skill_id, level) do
    before = PlayerSession.get_state(session.pid)
    row_before = Repo.get_by(Homunculus, character_id: before.game_state.character_id)
    clear_packet_inbox()

    cast(session.pid, skill_id, level)
    after_state = PlayerSession.get_state(session.pid)

    assert_lifecycle_unchanged(after_state, before, row_before)
    refute_packet_sent(SkillEffect)
    refute_packet_sent(ItemRemoved)
  end

  defp assert_lifecycle_unchanged(after_state, before, row_before) do
    assert after_state.game_state.inventory == before.game_state.inventory

    assert after_state.game_state.stats.current_state.sp ==
             before.game_state.stats.current_state.sp

    assert after_state.game_state.skill_cooldowns == before.game_state.skill_cooldowns
    assert after_state.homunculus == before.homunculus

    assert Repo.get_by(Homunculus, character_id: before.game_state.character_id) == row_before
  end

  defp remove_inventory_item(inventory, item_id) do
    index = Inventory.stackable_index(inventory, item_id)
    Inventory.remove(inventory, index, 1)
  end

  defp start_alchemist(item1, item2 \\ nil, opts \\ []) do
    character = insert_alchemist()
    if item1, do: seed_inventory(character.id, item1)
    if item2, do: seed_inventory(character.id, item2)
    if Keyword.get(opts, :insert_homunculus) == :dead, do: insert_dead_homunculus(character.id)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character, map_name: @map, position: {150, 150})
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp insert_alchemist do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "homskills#{uniq}",
        user_pass: "password",
        email: "homskills#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "HomSkills#{uniq}",
        class: @alchemist_class,
        base_level: 50,
        job_level: 50,
        hp: 5_000,
        max_hp: 5_000,
        sp: 500,
        max_sp: 500,
        learned_skills: %{"238" => 1, "243" => 1, "244" => 1, "247" => 5},
        last_map: @map,
        last_x: 150,
        last_y: 150
      })
      |> Repo.insert()

    character
  end

  defp insert_dead_homunculus(character_id) do
    {:ok, row} =
      %Homunculus{}
      |> Homunculus.changeset(%{
        character_id: character_id,
        class_id: 6001,
        name: "Lif",
        lifecycle: "dead",
        hp: 0,
        max_hp: 1_000,
        sp: 40,
        max_sp: 40,
        active_remaining_ms: 0
      })
      |> Repo.insert()

    row
  end

  defp seed_inventory(character_id, nameid) do
    {:ok, item} =
      InventoryPersistence.insert_item(character_id, %{nameid: nameid, amount: 1, identify: 1})

    item
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
    assert_eventually(fn -> predicate.(PlayerSession.get_state(pid)) end)
    PlayerSession.get_state(pid)
  end
end
