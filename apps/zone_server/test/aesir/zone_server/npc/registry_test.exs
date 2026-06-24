defmodule Aesir.ZoneServer.Npc.RegistryTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Npc.Verifier

  defmodule DiscoverableNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 199, y: 201, dir: 0, sprite: 58, name: "T"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule CollidingNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 199, y: 201, dir: 0, sprite: 58, name: "C"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule NotAnNpc do
    def spawn, do: []
  end

  setup do
    on_exit(fn -> :persistent_term.erase(Registry) end)
    Registry.reload([DiscoverableNpc, NotAnNpc])
    :ok
  end

  describe "reload/1" do
    test "keeps only modules declaring the Npc behaviour" do
      modules = Enum.map(Registry.entries(), fn {mod, _} -> mod end)

      assert DiscoverableNpc in modules
      refute NotAnNpc in modules
    end
  end

  describe "module_at/3" do
    test "resolves a discovered NPC's spawn cell to its module and placement" do
      assert {:ok, {DiscoverableNpc, %Placement{} = placement}} =
               Registry.module_at("prontera", 199, 201)

      assert placement.map == "prontera"
      assert placement.x == 199
      assert placement.y == 201
    end

    test "returns :error for a cell with no NPC" do
      assert :error = Registry.module_at("prontera", 1, 1)
    end
  end

  describe "entries/0" do
    test "lists discovered placements as un-collapsed {module, placement}" do
      assert {DiscoverableNpc, %Placement{}} =
               Enum.find(Registry.entries(), fn {mod, _} -> mod == DiscoverableNpc end)
    end

    test "keeps both NPCs on a shared cell so the verifier can flag the collision" do
      stub(MapCache, :walkable?, fn _, _, _ -> true end)
      Registry.reload([DiscoverableNpc, CollidingNpc])

      assert {:error, errors} = Verifier.verify(Registry.entries())
      assert Enum.any?(errors, &match?({:cell_collision, {"prontera", 199, 201}, _mods}, &1))
    end
  end

  describe "entity_id/1" do
    test "is deterministic for a placement and sits in the reserved NPC gid range" do
      {_module, placement} = hd(Registry.entries())

      gid = Registry.entity_id(placement)

      assert gid == Registry.entity_id(placement)
      assert gid in 0x5000_0000..0x57FF_FFFF
    end
  end

  describe "module_for_unit/1" do
    test "resolves a spawned NPC's unit id back to its module and placement" do
      {module, placement} = hd(Registry.entries())
      gid = Registry.entity_id(placement)

      assert {:ok, {^module, ^placement}} = Registry.module_for_unit(gid)
    end

    test "returns :error for a gid with no registered NPC" do
      assert :error = Registry.module_for_unit(0x5000_0000 - 1)
    end
  end
end
