defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionLingerTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestWait
  import Aesir.TestEtsSetup

  @moduletag :capture_log

  alias Aesir.Commons.Cluster
  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.SessionManager
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.Player.SkillCooldownPersistence
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @account_id 100
  @char_id 1

  setup {Aesir.MimicMode, :global}
  setup :setup_ets_tables

  setup do
    ClusterTestHelper.clear_all()
    test = self()

    Enum.each([Persistence, StatusPersistence, QuestPersistence], &Mimic.copy/1)
    stub(Persistence, :load_inventory, fn _char_id -> [] end)
    stub(StatusPersistence, :restore_on_spawn, fn state -> state end)
    stub(StatusPersistence, :save_statuses, fn char_id -> send(test, {:saved, char_id}) end)
    stub(SkillCooldownPersistence, :restore_on_spawn, fn state -> state end)
    stub(SkillCooldownPersistence, :save_cooldowns, fn _game_state -> :ok end)
    stub(QuestPersistence, :load_on_spawn, fn state -> state end)
    stub(CharacterPersistence, :update_position, fn _, _, _, _ -> {:ok, %Character{}} end)
    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    stub(CharacterPersistence, :update_character, fn _, _, _ -> {:ok, %Character{}} end)

    :ok =
      SessionManager.create_session(@account_id, %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 3,
        username: "linger"
      })

    connection = start_connection()

    {:ok, session} =
      GenServer.start(PlayerSession, %{character: character(), connection_pid: connection})

    on_exit(fn ->
      if Process.alive?(session), do: GenServer.stop(session)
      ClusterTestHelper.clear_all()
    end)

    {:ok, connection: connection, session: session}
  end

  test "a disconnect within the window lingers 10 s holding the presence", ctx do
    in_combat(ctx.session)
    ref = Process.monitor(ctx.session)
    connection_presence = presence_owner()

    Process.exit(ctx.connection, :kill)

    token = await_linger(ctx.session)
    assert Process.read_timer(token) in 9_000..10_000
    assert {:ok, _unit} = UnitRegistry.get_unit(:player, @char_id)

    assert_eventually(fn ->
      owner = presence_owner()
      owner != nil and owner != connection_presence
    end)

    assert {:ok, %{server_type: :zone_server}} = SessionManager.get_online_user(@account_id)

    send(ctx.session, {:timeout, make_ref(), {:logout, :linger_expired}})
    assert lingering(ctx.session) == token

    send(ctx.session, {:timeout, token, {:logout, :linger_expired}})

    assert_receive {:DOWN, ^ref, :process, _pid, :normal}

    assert_eventually(fn ->
      SessionManager.get_online_user(@account_id) == {:error, :not_found}
    end)
  end

  test "a disconnect outside the window stops at once", ctx do
    ref = Process.monitor(ctx.session)

    Process.exit(ctx.connection, :kill)

    assert_receive {:DOWN, ^ref, :process, _pid, :normal}
  end

  test "a player killed while lingering still leaves once at expiry", ctx do
    in_combat(ctx.session)
    ref = Process.monitor(ctx.session)
    Process.exit(ctx.connection, :kill)
    token = await_linger(ctx.session)

    PlayerSession.apply_damage(ctx.session, 1_000_000, {:mob, 2})
    assert_eventually(fn -> :sys.get_state(ctx.session).game_state.action_state == :dead end)

    send(ctx.session, {:timeout, token, {:logout, :linger_expired}})

    assert_receive {:DOWN, ^ref, :process, _pid, :normal}
    assert_received {:saved, @char_id}
    refute_received {:saved, _}
  end

  defp start_connection do
    test = self()

    connection =
      spawn(fn ->
        :ok = SessionManager.set_user_online(@account_id, :zone_server, @char_id, "prontera")
        send(test, :online)
        Process.sleep(:infinity)
      end)

    assert_receive :online, 2_000
    connection
  end

  defp presence_owner do
    case Horde.Registry.lookup(Cluster.registry(), {:online, @account_id}) do
      [{pid, _user}] -> pid
      [] -> nil
    end
  end

  defp in_combat(session),
    do: :sys.replace_state(session, &%{&1 | canlog_at: System.monotonic_time(:millisecond)})

  defp lingering(session), do: :sys.get_state(session).lingering

  defp await_linger(session) do
    assert_eventually(fn -> is_reference(lingering(session)) end)
    lingering(session)
  end

  defp character do
    %Character{
      id: @char_id,
      account_id: @account_id,
      name: "Lingerer",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      class: 1,
      base_level: 99,
      job_level: 50,
      sex: "M",
      head_top: 1,
      head_mid: 0,
      head_bottom: 0,
      hair_color: 0,
      clothes_color: 0,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10
    }
  end
end
