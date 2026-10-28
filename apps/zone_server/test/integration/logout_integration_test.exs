defmodule Aesir.ZoneServer.Integration.LogoutIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Cluster
  alias Aesir.Commons.SessionManager
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.Respawn
  alias Aesir.Net.RespawnResult
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    :ok
  end

  test "char select is refused right after an attack and allowed once the window has passed" do
    player = start_player_session(position: {150, 150})
    mob = start_mob_session(position: {151, 150}, hp: 100_000, max_hp: 100_000)
    on_exit(fn -> end_mob_session(mob) end)
    on_exit(fn -> end_player_session(player) end)

    simulate_incoming_message(player.pid, %ActionRequest{target_id: mob.unit_id, action: 0})
    assert eventually(fn -> :sys.get_state(player.pid).canlog_at != nil end)

    simulate_incoming_message(player.pid, %Respawn{type: 1})

    assert_packet_sent_with(RespawnResult, &match?(%RespawnResult{type: 1, ok: false}, &1))
    assert Process.alive?(player.pid)

    :sys.replace_state(player.pid, &%{&1 | canlog_at: &1.canlog_at - 10_001})
    ref = Process.monitor(player.pid)

    simulate_incoming_message(player.pid, %Respawn{type: 1})

    assert_receive {:DOWN, ^ref, :process, _pid, :normal}, 1_000
    refute_received {:packet_sent, %RespawnResult{}, _channel}
  end

  test "a connection lost right after a hit lingers 10 s, targetable and holding the account" do
    account_id = System.unique_integer([:positive])
    on_exit(fn -> SessionManager.end_session(account_id) end)

    :ok =
      SessionManager.create_session(account_id, %{
        login_id1: 1,
        login_id2: 2,
        auth_code: 3,
        username: "lgr#{account_id}"
      })

    connection = start_connection(account_id)
    on_exit(fn -> Process.exit(connection, :kill) end)
    connection_presence = presence_owner(account_id)

    player =
      start_player_session(
        account_id: account_id,
        connection_pid: connection,
        position: {150, 150}
      )

    on_exit(fn -> end_player_session(player) end)
    id = player.character.id

    mob = start_mob_session(position: {151, 150}, modes: [:can_move, :can_attack])
    on_exit(fn -> end_mob_session(mob) end)

    assert :ok = Combat.execute_mob_attack(get_mob_state(mob.pid), id)
    assert eventually(fn -> hp(player.pid) < 100 end)
    hp_at_disconnect = hp(player.pid)

    ref = Process.monitor(player.pid)
    Process.exit(connection, :kill)

    assert eventually(fn -> is_reference(:sys.get_state(player.pid).lingering) end)

    assert eventually(fn ->
             owner = presence_owner(account_id)
             owner != nil and owner != connection_presence
           end)

    assert {:ok, %{server_type: :zone_server}} = SessionManager.get_online_user(account_id)

    assert :ok = Combat.execute_mob_attack(get_mob_state(mob.pid), id)
    assert eventually(fn -> hp(player.pid) < hp_at_disconnect end)

    token = :sys.get_state(player.pid).lingering
    assert Process.read_timer(token) in 1..10_000
    send(player.pid, {:timeout, token, {:logout, :linger_expired}})

    assert_receive {:DOWN, ^ref, :process, _pid, :normal}, 1_000
    assert {:error, :not_found} = UnitRegistry.get_unit(:player, id)

    assert eventually(fn ->
             SessionManager.get_online_user(account_id) == {:error, :not_found}
           end)
  end

  # A stand-in for the zone QUIC connection: it holds the account's online
  # presence, as the real one does after the zone handshake, and is not linked
  # to the test so it can be killed.
  defp start_connection(account_id) do
    test = self()

    connection =
      spawn(fn ->
        :ok = SessionManager.set_user_online(account_id, :zone_server)
        send(test, :online)
        Process.sleep(:infinity)
      end)

    assert_receive :online, 2_000
    connection
  end

  defp presence_owner(account_id) do
    case Horde.Registry.lookup(Cluster.registry(), {:online, account_id}) do
      [{pid, _user}] -> pid
      [] -> nil
    end
  end

  defp hp(pid), do: get_player_state(pid).stats.current_state.hp
end
