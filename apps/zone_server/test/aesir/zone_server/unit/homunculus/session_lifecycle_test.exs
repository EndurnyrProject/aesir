defmodule Aesir.ZoneServer.Unit.Homunculus.SessionLifecycleTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Net.HomunculusPrivateState
  alias Aesir.Net.MapLoaded
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence, as: HomunculusPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  setup :verify_on_exit!
  setup {Aesir.MimicMode, :global}

  setup do
    Mimic.copy(HomunculusPersistence)

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "hom_session_#{System.unique_integer([:positive])}",
        user_pass: "password",
        email: "hom-session@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "HomSession#{System.unique_integer([:positive])}",
        class: 5,
        base_level: 50,
        job_level: 50,
        hp: 1_000,
        max_hp: 1_000,
        sp: 500,
        max_sp: 500,
        last_map: "hom_session_map",
        last_x: 50,
        last_y: 50
      })
      |> Repo.insert()

    {:ok, account: account, character: character}
  end

  for {lifecycle, hp} <- [{"active", 800}, {"rested", 800}, {"dead", 0}] do
    test "restores and publishes private state for #{lifecycle} login", %{character: character} do
      lifecycle = unquote(lifecycle)
      hp = unquote(hp)
      row = insert_homunculus(character.id, lifecycle, hp)
      character = Repo.preload(character, :homunculus)
      session = start_player_session(character: character)
      on_exit(fn -> stop_if_alive(session.pid) end)

      state = PlayerSession.get_state(session.pid)
      expected_lifecycle = String.to_existing_atom(lifecycle)
      assert state.homunculus.lifecycle == expected_lifecycle
      assert state.homunculus.id == row.id
      assert state.homunculus_runtime.clocks_online
      assert is_reference(state.homunculus_runtime.checkpoint_timer_ref)
      assert is_reference(state.homunculus_runtime.cooldown_timer_ref)

      if lifecycle == "active" do
        assert is_reference(state.homunculus_runtime.active_expiry_timer_ref)
        assert is_reference(state.homunculus_runtime.hunger_timer_ref)
        assert is_integer(state.homunculus.world_gid)

        assert {:ok, {HomunculusState, registered, pid}} =
                 UnitRegistry.get_unit(:homunculus, state.homunculus.world_gid)

        assert registered.world_gid == state.homunculus.world_gid
        assert pid == session.pid
      else
        assert is_nil(state.homunculus_runtime.active_expiry_timer_ref)
        assert is_nil(state.homunculus_runtime.hunger_timer_ref)
        assert is_nil(state.homunculus.world_gid)
        assert UnitRegistry.list_units_by_type(:homunculus) == []
      end

      assert_receive {:packet_sent, %HomunculusPrivateState{} = packet, :bulk}, 500
      assert packet.durable_id == row.id
      assert packet.lifecycle == lifecycle_enum(expected_lifecycle)
      refute state.homunculus_runtime.private_dirty

      send(session.pid, :spawn_player)

      assert_eventually(fn ->
        repeated = PlayerSession.get_state(session.pid)
        repeated.homunculus == state.homunculus and timer_refs(repeated) == timer_refs(state)
      end)

      refute_receive {:packet_sent, %HomunculusPrivateState{}, :bulk}, 100
    end
  end

  test "duplicate initial MapLoaded leaves Homunculus startup unchanged", %{character: character} do
    insert_homunculus(character.id, "active", 800)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    on_exit(fn -> stop_if_alive(session.pid) end)

    assert_receive {:packet_sent, %HomunculusPrivateState{}, :bulk}, 500
    before = PlayerSession.get_state(session.pid)
    gid = before.homunculus.world_gid
    refs = timer_refs(before)

    simulate_incoming_message(session.pid, %MapLoaded{})

    assert_eventually(fn ->
      Process.alive?(session.pid) and timer_refs(PlayerSession.get_state(session.pid)) == refs
    end)

    after_loaded = PlayerSession.get_state(session.pid)
    assert after_loaded.homunculus.world_gid == gid
    assert UnitRegistry.count_units_by_type(:homunculus) == 1
    refute_receive {:packet_sent, %HomunculusPrivateState{}, :bulk}, 200
  end

  test "active warp leaves first, preserves GID and deadlines, and re-enters adjacent", %{
    character: character
  } do
    insert_homunculus(character.id, "active", 800)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    on_exit(fn -> stop_if_alive(session.pid) end)
    assert_receive {:packet_sent, %HomunculusPrivateState{}, :bulk}, 500
    before = PlayerSession.get_state(session.pid)
    gid = before.homunculus.world_gid
    StatusStorage.apply_status(:homunculus, gid, :sc_test)

    destination = "hom_destination_map"
    map = MapData.new(destination, 100, 100)
    :ets.insert(EtsTable.table_for(:map_cache), {destination, map})

    PlayerSession.warp(session.pid, destination, 40, 40)

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).game_state.pending_map_load == :warp
    end)

    detached = PlayerSession.get_state(session.pid)
    assert detached.homunculus.world_gid == gid
    assert {:error, :not_found} = UnitRegistry.get_unit(:homunculus, gid)
    assert UnitRegistry.unit_id_exists?(gid)
    assert StatusStorage.has_status?(:homunculus, gid, :sc_test)

    assert detached.homunculus_runtime.active_deadline_ms ==
             before.homunculus_runtime.active_deadline_ms

    assert detached.homunculus.cooldowns == before.homunculus.cooldowns

    simulate_incoming_message(session.pid, %MapLoaded{})

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus.map_name == destination
    end)

    entered = PlayerSession.get_state(session.pid)
    assert entered.homunculus.world_gid == gid

    assert entered.homunculus_runtime.active_deadline_ms ==
             before.homunculus_runtime.active_deadline_ms

    assert entered.homunculus.cooldowns == before.homunculus.cooldowns
    assert abs(entered.homunculus.x - entered.game_state.x) <= 1
    assert abs(entered.homunculus.y - entered.game_state.y) <= 1

    refute {entered.homunculus.x, entered.homunculus.y} ==
             {entered.game_state.x, entered.game_state.y}

    assert Cell.traversable?(destination, entered.homunculus.x, entered.homunculus.y)
    session_pid = session.pid
    assert {:ok, {HomunculusState, _, ^session_pid}} = UnitRegistry.get_unit(:homunculus, gid)
    assert_receive {:packet_sent, %HomunculusPrivateState{world_gid: ^gid}, :bulk}, 500

    entered_refs = timer_refs(entered)
    simulate_incoming_message(session.pid, %MapLoaded{})

    assert_eventually(fn ->
      Process.alive?(session.pid) and
        timer_refs(PlayerSession.get_state(session.pid)) == entered_refs
    end)

    refute_receive {:packet_sent, %HomunculusPrivateState{}, :bulk}, 100
  end

  test "disconnect while detached releases the reserved GID", %{character: character} do
    insert_homunculus(character.id, "active", 800)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    gid = PlayerSession.get_state(session.pid).homunculus.world_gid
    StatusStorage.apply_status(:homunculus, gid, :sc_test)

    destination = "hom_detached_disconnect_map"
    :ets.insert(EtsTable.table_for(:map_cache), {destination, MapData.new(destination, 10, 10)})
    PlayerSession.warp(session.pid, destination, 5, 5)

    assert_eventually(fn ->
      UnitRegistry.get_unit(:homunculus, gid) == {:error, :not_found} and
        UnitRegistry.unit_id_exists?(gid)
    end)

    :ok = PlayerSession.disconnect(session.pid)
    refute UnitRegistry.unit_id_exists?(gid)
    refute StatusStorage.has_status?(:homunculus, gid, :sc_test)
  end

  for {homunculus_hp, expected_lifecycle, expected_dirty} <- [
        {800, :rested, true},
        {799, :active, false}
      ] do
    test "owner death at Homunculus HP #{homunculus_hp} resolves to #{expected_lifecycle}", %{
      character: character
    } do
      insert_homunculus(character.id, "active", unquote(homunculus_hp))
      character = Repo.preload(character, :homunculus)
      session = start_player_session(character: character)
      on_exit(fn -> stop_if_alive(session.pid) end)

      PlayerSession.apply_damage(session.pid, 100_000)

      expected = unquote(expected_lifecycle)

      assert_eventually(fn ->
        PlayerSession.get_state(session.pid).homunculus.lifecycle == expected
      end)

      assert HomunculusPersistence.load_for_character(character.id).lifecycle ==
               Atom.to_string(expected)

      state = PlayerSession.get_state(session.pid)
      assert state.homunculus_runtime.private_dirty == unquote(expected_dirty)
    end
  end

  test "successful hunger tick preserves the private dirty mark", %{character: character} do
    insert_homunculus(character.id, "active", 800)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    on_exit(fn -> stop_if_alive(session.pid) end)
    before = cancel_stored_timer(session.pid, :hunger_timer_ref)
    ref = before.homunculus_runtime.hunger_timer_ref

    send(session.pid, {:timeout, ref, {:homunculus, :hunger_tick}})

    assert_eventually(fn ->
      state = PlayerSession.get_state(session.pid)

      state.homunculus.hunger == before.homunculus.hunger - 1 and
        state.homunculus_runtime.private_dirty
    end)
  end

  test "owner-death persistence failure replaces only the active timer", %{
    character: character
  } do
    insert_homunculus(character.id, "active", 800)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    on_exit(fn -> stop_if_alive(session.pid) end)
    before = PlayerSession.get_state(session.pid)

    stub(HomunculusPersistence, :save_semantic, fn _row, _attrs -> {:error, :forced} end)
    PlayerSession.apply_damage(session.pid, 100_000)

    assert_eventually(fn ->
      state = PlayerSession.get_state(session.pid)

      state.homunculus.lifecycle == :active and
        state.homunculus_runtime.active_expiry_timer_ref !=
          before.homunculus_runtime.active_expiry_timer_ref
    end)

    failed = PlayerSession.get_state(session.pid)
    assert live_timer?(failed.homunculus_runtime.active_expiry_timer_ref)

    assert failed.homunculus_runtime.cooldown_timer_ref ==
             before.homunculus_runtime.cooldown_timer_ref

    assert failed.homunculus_runtime.hunger_timer_ref ==
             before.homunculus_runtime.hunger_timer_ref

    assert failed.homunculus_runtime.checkpoint_timer_ref ==
             before.homunculus_runtime.checkpoint_timer_ref
  end

  test "active-expiry persistence failure rearms one retry that later transitions", %{
    character: character
  } do
    insert_homunculus(character.id, "active", 800)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    on_exit(fn -> stop_if_alive(session.pid) end)
    attempts = :atomics.new(1, [])

    stub(HomunculusPersistence, :save_semantic, fn row, attrs ->
      if :atomics.add_get(attempts, 1, 1) == 1,
        do: {:error, :forced},
        else: call_original(HomunculusPersistence, :save_semantic, [row, attrs])
    end)

    before = make_active_due(session.pid)
    old_ref = before.homunculus_runtime.active_expiry_timer_ref
    send(session.pid, {:timeout, old_ref, {:homunculus, :active_expired}})

    assert_eventually(fn ->
      state = PlayerSession.get_state(session.pid)

      state.homunculus.lifecycle == :active and
        state.homunculus_runtime.active_expiry_timer_ref != old_ref
    end)

    failed = PlayerSession.get_state(session.pid)
    retry_ref = failed.homunculus_runtime.active_expiry_timer_ref
    assert live_timer?(retry_ref)

    assert failed.homunculus_runtime.cooldown_timer_ref ==
             before.homunculus_runtime.cooldown_timer_ref

    assert failed.homunculus_runtime.hunger_timer_ref ==
             before.homunculus_runtime.hunger_timer_ref

    assert failed.homunculus_runtime.checkpoint_timer_ref ==
             before.homunculus_runtime.checkpoint_timer_ref

    send(session.pid, {:timeout, retry_ref, {:homunculus, :active_expired}})

    assert_eventually(fn ->
      state = PlayerSession.get_state(session.pid)
      state.homunculus.lifecycle == :rested and state.homunculus_runtime.private_dirty
    end)
  end

  test "premature active-expiry failure retains the replacement timer", %{
    character: character
  } do
    insert_homunculus(character.id, "active", 800)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    on_exit(fn -> stop_if_alive(session.pid) end)
    stub(HomunculusPersistence, :save_semantic, fn _row, _attrs -> {:error, :forced} end)

    before = cancel_stored_timer(session.pid, :active_expiry_timer_ref)
    old_ref = before.homunculus_runtime.active_expiry_timer_ref
    send(session.pid, {:timeout, old_ref, {:homunculus, :active_expired}})

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus_runtime.active_expiry_timer_ref != old_ref
    end)

    failed = PlayerSession.get_state(session.pid)
    assert failed.homunculus == before.homunculus
    assert live_timer?(failed.homunculus_runtime.active_expiry_timer_ref)

    assert failed.homunculus_runtime.cooldown_timer_ref ==
             before.homunculus_runtime.cooldown_timer_ref
  end

  test "premature cooldown-expiry failure retains the replacement timer", %{
    character: character
  } do
    insert_homunculus(character.id, "active", 800)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    on_exit(fn -> stop_if_alive(session.pid) end)
    stub(HomunculusPersistence, :save_semantic, fn _row, _attrs -> {:error, :forced} end)

    before = cancel_stored_timer(session.pid, :cooldown_timer_ref)
    old_ref = before.homunculus_runtime.cooldown_timer_ref
    send(session.pid, {:timeout, old_ref, {:homunculus, :cooldowns_expired}})

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus_runtime.cooldown_timer_ref != old_ref
    end)

    failed = PlayerSession.get_state(session.pid)
    assert failed.homunculus == before.homunculus
    assert live_timer?(failed.homunculus_runtime.cooldown_timer_ref)

    assert failed.homunculus_runtime.active_expiry_timer_ref ==
             before.homunculus_runtime.active_expiry_timer_ref
  end

  test "cooldown persistence failure cancels its successor and retries old map", %{
    character: character
  } do
    insert_homunculus(character.id, "active", 800)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    on_exit(fn -> stop_if_alive(session.pid) end)
    attempts = :atomics.new(1, [])

    stub(HomunculusPersistence, :save_semantic, fn row, attrs ->
      if :atomics.add_get(attempts, 1, 1) == 1,
        do: {:error, :forced},
        else: call_original(HomunculusPersistence, :save_semantic, [row, attrs])
    end)

    before = make_cooldown_due(session.pid)
    old_ref = before.homunculus_runtime.cooldown_timer_ref
    send(session.pid, {:timeout, old_ref, {:homunculus, :cooldowns_expired}})

    assert_eventually(fn ->
      state = PlayerSession.get_state(session.pid)

      state.homunculus.cooldowns == before.homunculus.cooldowns and
        state.homunculus_runtime.cooldown_timer_ref != old_ref
    end)

    failed = PlayerSession.get_state(session.pid)
    retry_ref = failed.homunculus_runtime.cooldown_timer_ref
    assert live_timer?(retry_ref)

    assert failed.homunculus_runtime.active_expiry_timer_ref ==
             before.homunculus_runtime.active_expiry_timer_ref

    assert failed.homunculus_runtime.hunger_timer_ref ==
             before.homunculus_runtime.hunger_timer_ref

    assert failed.homunculus_runtime.checkpoint_timer_ref ==
             before.homunculus_runtime.checkpoint_timer_ref

    send(session.pid, {:timeout, retry_ref, {:homunculus, :cooldowns_expired}})

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).homunculus.cooldowns ==
        %{8_002 => before.homunculus.cooldowns[8_002]}
    end)
  end

  test "current checkpoint ref persists durable remainders and arms one successor", %{
    character: character
  } do
    insert_homunculus(character.id, "active", 800)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    on_exit(fn -> stop_if_alive(session.pid) end)
    before = PlayerSession.get_state(session.pid)
    ref = before.homunculus_runtime.checkpoint_timer_ref

    send(session.pid, {:timeout, ref, {:homunculus, :checkpoint}})

    assert_eventually(fn ->
      state = PlayerSession.get_state(session.pid)

      is_reference(state.homunculus_runtime.checkpoint_timer_ref) and
        state.homunculus_runtime.checkpoint_timer_ref != ref
    end)

    persisted = HomunculusPersistence.load_for_character(character.id)
    assert persisted.active_remaining_ms in 0..1_800_000
    assert persisted.cooldowns["8001"] in 0..30_000
  end

  test "abrupt kill leaves a ghost that reconnect activation removes", %{character: character} do
    row = insert_homunculus(character.id, "active", 800)
    character = Repo.preload(character, :homunculus)
    first = start_player_session(character: character)
    first_state = PlayerSession.get_state(first.pid)
    old_gid = first_state.homunculus.world_gid
    Process.unlink(first.pid)
    monitor = Process.monitor(first.pid)
    Process.exit(first.pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, _, :killed}, 500
    assert {:ok, {HomunculusState, _, dead_pid}} = UnitRegistry.get_unit(:homunculus, old_gid)
    refute Process.alive?(dead_pid)

    reloaded = character |> Repo.reload!() |> Repo.preload(:homunculus)
    second = start_player_session(character: reloaded)
    on_exit(fn -> stop_if_alive(second.pid) end)
    second_state = PlayerSession.get_state(second.pid)

    assert second_state.homunculus.id == row.id
    assert UnitRegistry.count_units_by_type(:homunculus) == 1
    second_pid = second.pid

    assert {:ok, {HomunculusState, _, ^second_pid}} =
             UnitRegistry.get_unit(:homunculus, second_state.homunculus.world_gid)
  end

  test "stale timeout is a no-op and graceful stop flushes and clears presence", %{
    character: character
  } do
    row = insert_homunculus(character.id, "active", 800)
    character = Repo.preload(character, :homunculus)
    session = start_player_session(character: character)
    state = PlayerSession.get_state(session.pid)
    gid = state.homunculus.world_gid

    send(session.pid, {:timeout, make_ref(), {:homunculus, :active_expired}})
    unchanged = PlayerSession.get_state(session.pid)
    assert unchanged.homunculus == state.homunculus
    assert unchanged.homunculus_runtime == state.homunculus_runtime

    :ok = PlayerSession.disconnect(session.pid)
    refute Process.alive?(session.pid)
    assert {:error, :not_found} = UnitRegistry.get_unit(:homunculus, gid)
    assert {:error, :not_found} = SpatialIndex.get_unit_position(:homunculus, gid)

    persisted = HomunculusPersistence.load_for_character(character.id)
    assert persisted.id == row.id
    assert persisted.lifecycle == "active"
    assert persisted.active_remaining_ms in 0..1_800_000
    assert persisted.cooldowns["8001"] in 0..30_000
  end

  defp insert_homunculus(character_id, lifecycle, hp) do
    active_remaining_ms = if lifecycle == "active", do: 1_800_000, else: 0

    %Homunculus{}
    |> Homunculus.changeset(%{
      character_id: character_id,
      class_id: 6_001,
      name: "Hildr",
      lifecycle: lifecycle,
      level: 50,
      hp: hp,
      max_hp: 1_000,
      sp: 150,
      max_sp: 200,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      active_remaining_ms: active_remaining_ms,
      learned_skills: %{"8001" => 1},
      cooldowns: %{"8001" => 30_000},
      ai_config: %{}
    })
    |> Repo.insert!()
  end

  defp timer_refs(state) do
    runtime = state.homunculus_runtime

    Map.take(runtime, [
      :active_expiry_timer_ref,
      :cooldown_timer_ref,
      :hunger_timer_ref,
      :checkpoint_timer_ref
    ])
  end

  defp live_timer?(ref), do: is_reference(ref) and is_integer(Process.read_timer(ref))

  defp cancel_stored_timer(pid, field) do
    :sys.replace_state(pid, fn state ->
      Process.cancel_timer(Map.fetch!(state.homunculus_runtime, field))
      state
    end)
  end

  defp make_active_due(pid) do
    :sys.replace_state(pid, fn state ->
      Process.cancel_timer(state.homunculus_runtime.active_expiry_timer_ref)
      runtime = %{state.homunculus_runtime | active_deadline_ms: Clock.now_ms() - 1}
      %{state | homunculus_runtime: runtime}
    end)
  end

  defp make_cooldown_due(pid) do
    :sys.replace_state(pid, fn state ->
      Process.cancel_timer(state.homunculus_runtime.cooldown_timer_ref)
      now = Clock.now_ms()
      future_deadline = now + 30_000
      cooldowns = %{8_001 => now - 1, 8_002 => future_deadline}
      homunculus = %{state.homunculus | cooldowns: cooldowns}
      %{state | homunculus: homunculus}
    end)
  end

  defp lifecycle_enum(:active), do: :HOMUNCULUS_LIFECYCLE_ACTIVE
  defp lifecycle_enum(:rested), do: :HOMUNCULUS_LIFECYCLE_RESTED
  defp lifecycle_enum(:dead), do: :HOMUNCULUS_LIFECYCLE_DEAD

  defp stop_if_alive(pid) do
    if Process.alive?(pid) do
      Process.unlink(pid)
      Process.exit(pid, :kill)
    end
  end
end
