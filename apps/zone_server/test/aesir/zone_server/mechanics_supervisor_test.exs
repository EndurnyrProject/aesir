defmodule Aesir.ZoneServer.MechanicsSupervisorTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.ShopVerifier
  alias Aesir.ZoneServer.Npc.Verifier, as: NpcVerifier
  alias Aesir.ZoneServer.Npc.Warps

  test "item scripts are compiled at zone boot" do
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

    assert {:ok, _spec} = Aesir.ZoneServer.MechanicsSupervisor.init([])

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
end
