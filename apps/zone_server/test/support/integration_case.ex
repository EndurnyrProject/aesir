defmodule Aesir.ZoneServer.IntegrationCase do
  @moduledoc """
  Base case for integration tests that run the full application stack.

  Outbound messages are captured via the fake connection process created by
  `Aesir.ZoneServer.SessionHelpers`, which forwards every `{:send, channel,
  {tag, struct}}` push to the test process as `{:packet_sent, struct, channel}`.
  This allows testing real game mechanics end-to-end while keeping network I/O
  deterministic.

  ## Isolation

  Each test boots its OWN ETS world: the EtsTable is started with a fresh random
  seed (the same mechanism `TestEtsSetup` uses for unit tests) and that seed is
  placed in the test process dictionary. Every unit the test hand-spawns
  (`PlayerSession`, `MobSession`, ...) resolves its `seedN_*` tables via
  `ProcessTree`, so tests are fully isolated from each other and from the
  globally-booted (`nil` seed) coordinators. A fresh seed also starts with empty
  definition/cache tables, so `MapCache` and status definitions are re-initialised
  per test.

  Immutable boot state that legitimately lives on the `nil` tables (the `MapCache`
  walkability file, status definitions) is re-created into each per-test seed on
  demand. Tests that need a map's `Coordinator` must start their own under
  `start_supervised/1` against the current seed rather than consulting the
  globally-booted `MapManager`.
  """

  use ExUnit.CaseTemplate

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.PacketHelpers
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use ExUnit.Case, async: false
      use Mimic

      @moduletag :integration

      import Aesir.TestEtsSetup
      import Aesir.TestWait
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

  setup _tags do
    Mimic.set_mimic_private()

    :ok = Sandbox.checkout(Aesir.Repo)
    Sandbox.mode(Aesir.Repo, {:shared, self()})

    prev_inline = Application.get_env(:zone_server, :inline_persistence)
    Application.put_env(:zone_server, :inline_persistence, true)
    on_exit(fn -> restore_inline_persistence(prev_inline) end)

    # Per-test seeded EtsTable + process-dict seed (mirrors TestEtsSetup). Every
    # hand-spawned unit inherits this seed via ProcessTree, giving true isolation.
    seed = 5 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    _pid = start_supervised({EtsTable, seed: seed}, [])
    Process.put({EtsTable, :seed}, seed)

    # A fresh seed starts with empty definition/cache tables; re-create them so
    # hand-spawned units can walk maps and apply statuses.
    :ok = MapCache.init()
    :ok = Interpreter.init()
    # Pre-warm an empty warp index so `Warps.for_map/1` returns `:error` without
    # triggering the lazy loader (mirrors TestEtsSetup). Tests exercising real warp
    # data erase this and call `Warps.reload/0`.
    :persistent_term.put(Aesir.ZoneServer.Npc.Warps, %{by_map: %{}})

    # Start per-test background world-driving managers against this seed so
    # status expiries/ticks and ground-skill units operate on the test's own
    # tables instead of the boot `nil`-seeded singleton. Skill.Unit.Manager's
    # `default_server/0` already resolves `ProcessTree.get({__MODULE__, :server})`
    # or falls back to the registered global; StatusTickManager now mirrors that.
    # Each is started unnamed and pointed at via the process dictionary, so the
    # boot-named singletons stay untouched for other tests.
    status_tick =
      start_supervised!(
        {Aesir.ZoneServer.Mmo.StatusTickManager, name: nil},
        []
      )

    Process.put({Aesir.ZoneServer.Mmo.StatusTickManager, :server}, status_tick)

    skill_unit =
      start_supervised!(
        %{
          id: {:integration_default, Aesir.ZoneServer.Mmo.Skill.Unit.Manager},
          start: {Aesir.ZoneServer.Mmo.Skill.Unit.Manager, :start_link, [[name: nil]]}
        },
        []
      )

    Process.put({Aesir.ZoneServer.Mmo.Skill.Unit.Manager, :server}, skill_unit)
    on_exit(fn -> clean_manager_servers() end)

    # NPC event/script coroutines (donpcevent, OnInit timers, on_talk) spawn as
    # tasks under the boot-global InteractionSupervisor, which resolves `nil`
    # tables. Start a per-test one so those tasks inherit this test's seed and
    # can see hand-spawned observers/players.
    npc_interaction = start_supervised!(Task.Supervisor, [])
    Process.put({Aesir.ZoneServer.Npc.InteractionSupervisor, :server}, npc_interaction)

    # NPC Session GenServers (OnTimer/OnInit/OnTouch event state) must run under
    # this test's seed too, or their dispatched tasks resolve the boot `nil`
    # tables and can't see hand-spawned observers. Start per-test registry +
    # dynamic supervisor and point Npc.Session at them via ProcessTree.
    npc_session_registry_name = :"session_registry_#{byte_size(seed)}_#{:erlang.unique_integer()}"

    _npc_session_registry =
      start_supervised!(
        %{
          id: {:integration_default, Aesir.ZoneServer.Npc.SessionRegistry},
          start: {Registry, :start_link, [[keys: :unique, name: npc_session_registry_name]]}
        },
        []
      )

    Process.put({Aesir.ZoneServer.Npc.SessionRegistry, :server}, npc_session_registry_name)

    npc_session_dyn =
      start_supervised!(
        %{
          id: {:integration_default, Aesir.ZoneServer.Npc.SessionDynamicSupervisor},
          start:
            {DynamicSupervisor, :start_link,
             [[name: nil, strategy: :one_for_one, max_restarts: 5, max_seconds: 60]]}
        },
        []
      )

    Process.put({Aesir.ZoneServer.Npc.SessionDynamicSupervisor, :server}, npc_session_dyn)

    # Most integration tests run on "prontera". Start a per-test seeded map
    # world (Coordinator + MobSupervisor) so drops/loot/pickup route through
    # this test's own tables instead of the globally-booted `nil`-seeded
    # coordinator. Tests on other maps call `start_per_test_map/1`.
    start_per_test_map("prontera")

    {:ok,
     %{
       test_pid: self(),
       seed: seed,
       status_tick_manager: status_tick,
       skill_unit_manager: skill_unit
     }}
  end

  defp clean_manager_servers do
    Process.delete({Aesir.ZoneServer.Mmo.StatusTickManager, :server})
    Process.delete({Aesir.ZoneServer.Mmo.Skill.Unit.Manager, :server})
    Process.delete({Aesir.ZoneServer.Npc.InteractionSupervisor, :server})
    Process.delete({Aesir.ZoneServer.Npc.SessionRegistry, :server})
    Process.delete({Aesir.ZoneServer.Npc.SessionDynamicSupervisor, :server})
    :ok
  end

  @doc """
  Boots a per-test seeded world for `map_name`: a per-test `Map.Coordinator` and
  its `MobSupervisor`, pointed at via `ProcessTree` so `Coordinator.drop_items`,
  `claim_item`, `mob_died`, etc. write to this test's own seeded tables instead of
  the globally-booted `nil`-seeded coordinator. The supervisor is supervised for
  the test and torn down automatically.
  """
  def start_per_test_map(map_name) do
    mob_sup =
      start_supervised!(
        %{
          id: {Aesir.ZoneServer.Unit.Mob.MobSupervisor, map_name},
          start: {Aesir.ZoneServer.Unit.Mob.MobSupervisor, :start_link, [map_name, [name: nil]]}
        },
        []
      )

    Process.put({Aesir.ZoneServer.Unit.Mob.MobSupervisor, map_name}, mob_sup)

    coord =
      start_supervised!(
        %{
          id: {:coordinator, map_name},
          start:
            {Aesir.ZoneServer.Map.Coordinator, :start_link, [[map_name: map_name, name: nil]]}
        },
        []
      )

    Process.put({Aesir.ZoneServer.Map.Coordinator, map_name}, coord)
    on_exit(fn -> clean_map_servers(map_name) end)
    {:ok, coord}
  end

  defp clean_map_servers(map_name) do
    Process.delete({Aesir.ZoneServer.Unit.Mob.MobSupervisor, map_name})
    Process.delete({Aesir.ZoneServer.Map.Coordinator, map_name})
    :ok
  end

  defp restore_inline_persistence(nil),
    do: Application.delete_env(:zone_server, :inline_persistence)

  defp restore_inline_persistence(value),
    do: Application.put_env(:zone_server, :inline_persistence, value)

  # A per-test seeded world starts clean; no shared-table wipe is needed.

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
