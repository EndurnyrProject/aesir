defmodule Aesir.ZoneServer.Script.DslNpcInfoTest do
  @moduledoc """
  Covers the registry-backed NPC read ops `getnpcid/2` (resolve a named NPC's
  gid) and `strnpcinfo/2` (a field of the running NPC's info), both driven off
  the real `Npc.Registry`.
  """

  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl

  defmodule InfoNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{
          map: "morocc",
          x: 200,
          y: 90,
          sprite: 58,
          name: "Info Broker",
          unique_name: "info_broker"
        }
      ]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule HiddenNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{
          map: "morocc",
          x: 210,
          y: 90,
          sprite: 58,
          name: "Creature",
          unique_name: "Creature#01"
        }
      ]

    @impl true
    def on_talk(ctx), do: ctx
  end

  setup do
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([InfoNpc, HiddenNpc])

    placement = hd(InfoNpc.spawn())
    hidden_placement = hd(HiddenNpc.spawn())

    {:ok,
     gid: NpcRegistry.entity_id(placement), hidden_gid: NpcRegistry.entity_id(hidden_placement)}
  end

  describe "getnpcid/2" do
    test "returns the gid of the placement registered under the name", %{gid: gid} do
      ctx = Ctx.detached(InfoNpc, gid)
      assert Dsl.getnpcid(ctx, "info_broker") == gid
    end

    test "returns 0 for an unknown name" do
      ctx = Ctx.detached(InfoNpc, 1)
      assert Dsl.getnpcid(ctx, "nobody") == 0
    end
  end

  describe "strnpcinfo/2" do
    test "reads the visible name, unique name and map of the running NPC", %{gid: gid} do
      ctx = Ctx.detached(InfoNpc, gid)

      assert Dsl.strnpcinfo(ctx, 0) == "Info Broker"
      assert Dsl.strnpcinfo(ctx, 1) == "Info Broker"
      assert Dsl.strnpcinfo(ctx, 3) == "info_broker"
      assert Dsl.strnpcinfo(ctx, 4) == "morocc"
    end

    test "returns an empty string for a missing hidden fragment and the unmodelled path",
         %{gid: gid} do
      ctx = Ctx.detached(InfoNpc, gid)

      assert Dsl.strnpcinfo(ctx, 2) == ""
      assert Dsl.strnpcinfo(ctx, 5) == ""
    end

    test "reads the hidden fragment from a full-name unique_name", %{hidden_gid: hidden_gid} do
      ctx = Ctx.detached(HiddenNpc, hidden_gid)

      assert Dsl.strnpcinfo(ctx, 0) == "Creature#01"
      assert Dsl.strnpcinfo(ctx, 1) == "Creature"
      assert Dsl.strnpcinfo(ctx, 2) == "01"
      assert Dsl.strnpcinfo(ctx, 3) == "Creature#01"
    end

    test "returns an empty string when there is no npc_gid" do
      ctx = %{Ctx.detached(InfoNpc, 1) | npc_gid: nil}
      assert Dsl.strnpcinfo(ctx, 0) == ""
    end

    test "returns an empty string when the npc_gid does not resolve" do
      ctx = Ctx.detached(InfoNpc, 999_999)
      assert Dsl.strnpcinfo(ctx, 0) == ""
    end
  end
end
