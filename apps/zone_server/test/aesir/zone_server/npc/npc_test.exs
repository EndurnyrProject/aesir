defmodule Aesir.ZoneServer.NpcTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Placement

  defmodule SampleNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 150, y: 150, dir: 0, sprite: 58, name: "T"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  describe "use Aesir.ZoneServer.Npc" do
    test "exposes a stable npc_id/0 atom" do
      assert is_atom(SampleNpc.npc_id())
      assert SampleNpc.npc_id() == SampleNpc.npc_id()
    end

    test "exposes spawn/0 normalized to Placement structs" do
      assert [%Placement{} = placement] = SampleNpc.spawn()

      assert placement.map == "prontera"
      assert placement.x == 150
      assert placement.y == 150
      assert placement.dir == 0
      assert placement.sprite == 58
      assert placement.name == "T"
    end

    test "declares the Npc behaviour" do
      assert Aesir.ZoneServer.Npc in (SampleNpc.module_info(:attributes)[:behaviour] || [])
    end
  end
end
