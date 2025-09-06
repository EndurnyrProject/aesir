defmodule Aesir.ZoneServer.IntegrationCase do
  @moduledoc """
  Base case for integration tests that run the full application stack
  with only the network layer (Connection) mocked.

  This allows testing real game mechanics end-to-end while maintaining
  control over network I/O for deterministic tests.
  """

  use ExUnit.CaseTemplate
  import Mimic

  alias Aesir.ZoneServer.PacketHelpers
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use ExUnit.Case, async: false
      use Mimic

      import Aesir.TestEtsSetup
      import Aesir.ZoneServer.IntegrationCase
      import Aesir.ZoneServer.PacketHelpers
      import Aesir.ZoneServer.SessionHelpers, except: [get_player_state: 1, get_mob_state: 1]
      import Aesir.ZoneServer.EntityHelpers
      import Aesir.ZoneServer.WorldHelpers

      alias Aesir.Commons.Network.Connection
      alias Aesir.ZoneServer.Unit.Mob.MobSession
      alias Aesir.ZoneServer.Unit.Player.PlayerSession
      alias Aesir.ZoneServer.Unit.SpatialIndex
      alias Aesir.ZoneServer.Unit.UnitRegistry
    end
  end

  setup tags do
    # Set up database sandbox in shared mode since we're async: false
    :ok = Sandbox.checkout(Aesir.Repo)
    Sandbox.mode(Aesir.Repo, {:shared, self()})

    # Set up Mimic
    Mimic.copy(Aesir.Commons.Network.Connection)

    # Set up ETS tables needed by the zone server
    setup_ets_tables(tags)

    # Capture test process PID for packet routing
    test_pid = self()

    # Mock Connection to capture packets instead of sending over network
    stub(Aesir.Commons.Network.Connection, :send_packet, fn _conn_pid, packet ->
      # Capture both the packet struct and its built binary form
      packet_binary = packet.__struct__.build(packet)
      send(test_pid, {:packet_sent, packet, packet_binary})
      :ok
    end)

    # Return test context
    {:ok, %{test_pid: test_pid}}
  end

  # Import the ETS setup helper
  def setup_ets_tables(_tags) do
    # Create the ETS tables needed for UnitRegistry and SpatialIndex
    :ets.new(UnitRegistry, [:set, :public, :named_table])
    :ets.new(SpatialIndex, [:set, :public, :named_table])

    # Also create any map-specific spatial index tables as needed
    :ets.new(:spatial_index_prontera, [:bag, :public, :named_table])

    :ok
  end

  @doc """
  Asserts that a packet of a specific type was sent.
  Waits for the specified timeout (default 100ms) to handle async operations.
  Uses PacketHelpers.collect_packets_of_type to collect matching packets.

  ## Examples

      assert_packet_sent(ZcNotifyActentry)
      assert_packet_sent(ZcNotifyMoveentry, 200)
  """
  def assert_packet_sent(packet_type, timeout \\ 100) do
    packets = PacketHelpers.collect_packets_of_type(packet_type, timeout)

    assert length(packets) > 0,
           "Expected packet type #{inspect(packet_type)} but none were sent"

    hd(packets)
  end

  @doc """
  Asserts that a packet was sent and allows inspection of its payload.
  The provided function should perform assertions on the packet.

  ## Examples

      assert_packet_sent_with(ZcNotifyActentry, fn packet ->
        assert packet.target_id == target.id
        assert packet.damage > 0
      end)
  """
  def assert_packet_sent_with(packet_type, assertion_fn, timeout \\ 100)
      when is_function(assertion_fn, 1) do
    packet = assert_packet_sent(packet_type, timeout)
    assertion_fn.(packet)
    packet
  end

  @doc """
  Refutes that a packet of a specific type was sent within the timeout period.

  ## Examples

      refute_packet_sent(ZcErrorPacket)
  """
  def refute_packet_sent(packet_type, timeout \\ 100) do
    refute_receive {:packet_sent, %{__struct__: ^packet_type}, _}, timeout
  end

  @doc """
  Flushes all packets currently in the mailbox.
  Useful for clearing initialization packets before testing specific behavior.

  ## Examples

      flush_packets()
  """
  def flush_packets do
    receive do
      {:packet_sent, _, _} -> flush_packets()
    after
      50 -> :ok
    end
  end

  @doc """
  Captures all packets sent during the execution of the given function.
  Returns a tuple of {result, packets} where result is the return value
  of the function and packets is a list of all captured packets.

  ## Examples

      {result, packets} = capture_packets(fn ->
        Combat.execute_attack(stats, player_state, target_id)
      end)

      assert length(packets) == 2
  """
  def capture_packets(fun) when is_function(fun, 0) do
    test_pid = self()

    # Temporarily redirect packet capture
    packets_ref = make_ref()
    collector_pid = spawn_link(fn -> collect_packets([], packets_ref, test_pid) end)

    # Re-stub to send to collector
    stub(Aesir.Commons.Network.Connection, :send_packet, fn _conn_pid, packet ->
      packet_binary = packet.__struct__.build(packet)
      send(collector_pid, {:packet, packet, packet_binary})
      :ok
    end)

    # Execute the function
    result = fun.()

    # Small delay to ensure all async packets are collected
    Process.sleep(50)

    # Collect captured packets
    send(collector_pid, {:get_packets, self()})

    receive do
      {^packets_ref, packets} -> {result, packets}
    after
      1000 -> {result, []}
    end
  end

  # Private helper for packet collection
  defp collect_packets(packets, ref, test_pid) do
    receive do
      {:packet, packet, binary} ->
        collect_packets([{packet, binary} | packets], ref, test_pid)

      {:get_packets, reply_to} ->
        send(reply_to, {ref, Enum.reverse(packets)})
    end
  end
end
