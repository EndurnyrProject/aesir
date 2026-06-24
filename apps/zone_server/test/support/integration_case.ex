defmodule Aesir.ZoneServer.IntegrationCase do
  @moduledoc """
  Base case for integration tests that run the full application stack.

  Outbound messages are captured via the fake connection process created by
  `Aesir.ZoneServer.SessionHelpers`, which forwards every `{:send, channel,
  {tag, struct}}` push to the test process as `{:packet_sent, struct, channel}`.
  This allows testing real game mechanics end-to-end while keeping network I/O
  deterministic.
  """

  use ExUnit.CaseTemplate

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

    # Run character persistence inline (synchronously) for integration tests.
    # The fire-and-forget task otherwise races the sandbox teardown, and its
    # expected failure logs (in-memory characters absent from the DB) land outside
    # the test body. Inline writes happen within the body, where @moduletag
    # :capture_log covers them. The real async path stays covered by the
    # CharacterPersistence unit tests.
    prev_inline = Application.get_env(:zone_server, :inline_persistence)
    Application.put_env(:zone_server, :inline_persistence, true)
    on_exit(fn -> restore_inline_persistence(prev_inline) end)

    # Set up ETS tables needed by the zone server
    setup_ets_tables(tags)

    # The fake connection process forwards outbound pushes here as
    # {:packet_sent, struct, channel}; no network mocking required.
    {:ok, %{test_pid: self()}}
  end

  defp restore_inline_persistence(nil),
    do: Application.delete_env(:zone_server, :inline_persistence)

  defp restore_inline_persistence(value),
    do: Application.put_env(:zone_server, :inline_persistence, value)

  # Import the ETS setup helper
  def setup_ets_tables(_tags) do
    # Create the ETS tables needed for UnitRegistry and SpatialIndex
    :ets.new(UnitRegistry, [:set, :public, :named_table])
    :ets.new(SpatialIndex, [:set, :public, :named_table])

    # Also create any map-specific spatial index tables as needed
    :ets.new(:spatial_index_prontera, [:bag, :public, :named_table])

    # Pre-warm an empty warp index so `Warps.for_map/1` returns `:error`
    # without triggering the lazy loader (which would otherwise sanitize the
    # real warp files against the un-stubbed MapCache). Mirrors TestEtsSetup.
    :persistent_term.put(Aesir.ZoneServer.Npc.Warps, %{by_map: %{}})

    :ok
  end

  @doc """
  Asserts that a packet of a specific type was sent.
  Waits for the specified timeout (default 100ms) to handle async operations.
  Uses PacketHelpers.collect_packets_of_type to collect matching packets.

  ## Examples

      assert_packet_sent(ZcNotifyActentry)
      assert_packet_sent(Aesir.Net.UnitSpawn, 200)
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
end
