defmodule Aesir.ZoneServer.MechanicsSupervisorTest do
  # DataCase, not a bare ExUnit case: boot may reconcile pending boss respawn
  # deadlines, so `init/1` can need a checked-out sandbox connection. Under test
  # the reconciliation is config-gated off, but a test that enables it needs the
  # sandbox present.
  use Aesir.DataCase, async: false

  import Mimic

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.MechanicsSupervisor
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.MobSkill.Db, as: MobSkillDb
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.CastleVerifier
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Mmo.Woe.Scheduler
  alias Aesir.ZoneServer.Mmo.Woe.Server
  alias Aesir.ZoneServer.Npc.ClockScheduler
  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.ShopVerifier
  alias Aesir.ZoneServer.Npc.Verifier, as: NpcVerifier
  alias Aesir.ZoneServer.Npc.Warps

  test "item scripts are compiled at zone boot" do
    assert {:ok, _spec} = MechanicsSupervisor.init([])

    assert Code.ensure_loaded?(CompiledItemScripts)
    assert function_exported?(CompiledItemScripts, :on_use, 2)
  end

  test "boot runs OnInit after loading and verifying the NPC registry" do
    test_pid = self()

    stub(MapCache, :init, fn -> :ok end)
    stub(Interpreter, :init, fn -> :ok end)
    stub(ScriptCompiler, :compile_all!, fn -> :ok end)
    stub(Warps, :reload, fn -> :ok end)
    stub(Shops, :reload, fn -> :ok end)
    stub(Shops, :all, fn -> [] end)
    stub(MobSkillDb, :reload, fn -> :ok end)
    stub(LevelPenalty, :reload, fn -> :ok end)
    stub(RefineDatabase, :reload, fn -> :ok end)
    stub(ShopVerifier, :verify!, fn _shops -> :ok end)

    stub(NpcRegistry, :reload, fn ->
      send(test_pid, :registry_reloaded)
      %{entries: []}
    end)

    stub(NpcVerifier, :verify!, fn _entries ->
      send(test_pid, :verified)
      :ok
    end)

    stub(NpcEvents, :run_on_init, fn ->
      send(test_pid, :on_init_ran)
      :ok
    end)

    assert {:ok, _spec} = MechanicsSupervisor.init([])

    events =
      for _step <- 1..3 do
        receive do
          message -> message
        after
          1_000 -> flunk("mechanics boot step did not run")
        end
      end

    assert events == [:registry_reloaded, :verified, :on_init_ran]
  end

  test "boot excludes Woe.Server, Woe.Scheduler, and ClockScheduler under test" do
    stub(MapCache, :init, fn -> :ok end)
    stub(Interpreter, :init, fn -> :ok end)
    stub(ScriptCompiler, :compile_all!, fn -> :ok end)
    stub(Warps, :reload, fn -> :ok end)
    stub(Shops, :reload, fn -> :ok end)
    stub(Shops, :all, fn -> [] end)
    stub(MobSkillDb, :reload, fn -> :ok end)
    stub(LevelPenalty, :reload, fn -> :ok end)
    stub(RefineDatabase, :reload, fn -> :ok end)
    stub(ShopVerifier, :verify!, fn _shops -> :ok end)
    stub(NpcRegistry, :reload, fn -> %{entries: []} end)
    stub(NpcVerifier, :verify!, fn _entries -> :ok end)
    stub(NpcEvents, :run_on_init, fn -> :ok end)
    stub(CastleDb, :reload, fn -> :ok end)
    stub(MapFlags, :reload, fn -> :ok end)
    stub(CastleStore, :init, fn -> :ok end)
    stub(CastleStore, :hydrate, fn _owners -> :ok end)
    stub(Persistence, :load_all, fn -> %{} end)
    stub(CastleVerifier, :verify!, fn -> :ok end)

    assert {:ok, {_flags, children}} = MechanicsSupervisor.init([])

    child_ids = Enum.map(children, & &1.id)

    refute Server in child_ids
    refute Scheduler in child_ids
    refute ClockScheduler in child_ids
  end
end
