defmodule Aesir.ZoneServer.Script.DslAnnounceTest do
  @moduledoc """
  Covers the announce/mapannounce/areaannounce/broadcast DSL ops: pure
  side-effect broadcasting that decodes the rAthena flag and routes to the
  `Announcement` delivery module by scope, with detached-ctx and status-error
  short-circuits.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Bitwise

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "prontera"
  @area_size 14

  setup :verify_on_exit!

  setup do
    stub_announcement()
    :ok
  end

  describe "announce/3,4" do
    test "global scope calls to_all with decoded style and default color" do
      ctx = attached_ctx(150, 150)

      assert Dsl.announce(ctx, "hi", flag("bc_all")) == ctx

      assert_receive {:to_all, opts}
      assert opts == %{text: "hi", color: 0, style: :TOP, source_name: ""}
    end

    test "bc_all|bc_blue resolves the blue color" do
      ctx = attached_ctx(150, 150)

      assert Dsl.announce(ctx, "hi", flag("bc_all") ||| flag("bc_blue")) == ctx

      assert_receive {:to_all, opts}
      {:ok, blue} = Flags.value("bc_blue")
      %{color: expected} = Flags.decode(blue, 0)
      assert opts.color == expected
      assert opts.color != 0
    end

    test "self scope calls to_self with the char_id" do
      ctx = attached_ctx(150, 150)

      assert Dsl.announce(ctx, "hi", flag("bc_self")) == ctx

      assert_receive {:to_self, char_id, opts}
      assert char_id == ctx.char_id
      assert opts == %{text: "hi", color: 0, style: :LOCAL, source_name: ""}
    end

    test "map scope targets the player's current map" do
      ctx = attached_ctx(150, 150)

      assert Dsl.announce(ctx, "hi", flag("bc_map")) == ctx

      assert_receive {:to_map, @map, opts}
      assert opts.style == :CENTER
    end

    test "area scope builds a square rectangle around the player position" do
      ctx = attached_ctx(100, 200)

      assert Dsl.announce(ctx, "hi", flag("bc_area")) == ctx

      assert_receive {:to_area, @map, rect, opts}
      assert rect == {100 - @area_size, 200 - @area_size, 100 + @area_size, 200 + @area_size}
      assert opts.style == :CENTER
    end

    test "custom color argument overrides the flag color" do
      ctx = attached_ctx(150, 150)

      assert Dsl.announce(ctx, "hi", flag("bc_all"), 0xFF0000) == ctx

      assert_receive {:to_all, opts}
      assert opts.color == 0xFF0000
    end

    test "detached ctx with self scope returns ctx unchanged and delivers nothing" do
      ctx = detached_ctx()

      assert Dsl.announce(ctx, "hi", flag("bc_self")) == ctx

      refute_received {:to_self, _, _}
      refute_received {:to_map, _, _}
      refute_received {:to_area, _, _, _}
    end

    test "detached ctx with area scope returns ctx unchanged and delivers nothing" do
      ctx = detached_ctx()

      assert Dsl.announce(ctx, "hi", flag("bc_area")) == ctx

      refute_received {:to_area, _, _, _}
    end

    test "detached ctx with global scope still delivers" do
      ctx = detached_ctx()

      assert Dsl.announce(ctx, "hi", flag("bc_all")) == ctx

      assert_receive {:to_all, _opts}
    end

    test "short-circuits on an already-halted ctx" do
      ctx = Ctx.halt(attached_ctx(150, 150), :boom)

      assert Dsl.announce(ctx, "hi", flag("bc_all")) == ctx

      refute_received {:to_all, _}
    end
  end

  describe "mapannounce/4,5" do
    test "delivers to the named map with center style" do
      ctx = detached_ctx()

      assert Dsl.mapannounce(ctx, "prontera", "hi", 0) == ctx

      assert_receive {:to_map, "prontera", opts}
      assert opts == %{text: "hi", color: 0, style: :CENTER, source_name: ""}
    end

    test "the flag only supplies color" do
      ctx = detached_ctx()

      assert Dsl.mapannounce(ctx, "prontera", "hi", flag("bc_blue")) == ctx

      assert_receive {:to_map, "prontera", opts}
      {:ok, blue} = Flags.value("bc_blue")
      %{color: expected} = Flags.decode(blue, 0)
      assert opts.color == expected
    end

    test "short-circuits on a halted ctx" do
      ctx = Ctx.halt(detached_ctx(), :boom)

      assert Dsl.mapannounce(ctx, "prontera", "hi", 0) == ctx

      refute_received {:to_map, _, _}
    end
  end

  describe "areaannounce/8,9" do
    test "delivers to the rectangle on the named map" do
      ctx = detached_ctx()

      assert Dsl.areaannounce(ctx, "prontera", 10, 10, 20, 20, "hi", 0) == ctx

      assert_receive {:to_area, "prontera", rect, opts}
      assert rect == {10, 10, 20, 20}
      assert opts == %{text: "hi", color: 0, style: :CENTER, source_name: ""}
    end

    test "the trailing color argument is honored" do
      ctx = detached_ctx()

      assert Dsl.areaannounce(ctx, "prontera", 10, 10, 20, 20, "hi", 0, 0xABCDEF) == ctx

      assert_receive {:to_area, "prontera", _rect, opts}
      assert opts.color == 0xABCDEF
    end
  end

  describe "broadcast/3,4" do
    test "is a global alias delivering via to_all" do
      ctx = detached_ctx()

      assert Dsl.broadcast(ctx, "hi", 0) == ctx

      assert_receive {:to_all, opts}
      assert opts == %{text: "hi", color: 0, style: :TOP, source_name: ""}
    end

    test "short-circuits on a halted ctx" do
      ctx = Ctx.halt(detached_ctx(), :boom)

      assert Dsl.broadcast(ctx, "hi", 0) == ctx

      refute_received {:to_all, _}
    end
  end

  defp flag(name) do
    {:ok, value} = Flags.value(name)
    value
  end

  defp stub_announcement do
    stub(Announcement, :to_all, fn opts -> send(self(), {:to_all, opts}) end)
    stub(Announcement, :to_self, fn char_id, opts -> send(self(), {:to_self, char_id, opts}) end)
    stub(Announcement, :to_map, fn map, opts -> send(self(), {:to_map, map, opts}) end)

    stub(Announcement, :to_area, fn map, rect, opts ->
      send(self(), {:to_area, map, rect, opts})
    end)
  end

  defp attached_ctx(x, y) do
    game_state = %{PlayerState.new(character(1)) | x: x, y: y, map_name: @map}

    %Ctx{
      char_id: game_state.character_id,
      account_id: game_state.account_id,
      connection_pid: self(),
      game_state: game_state,
      source: {:item, 1},
      session_pid: self()
    }
  end

  defp detached_ctx do
    %Ctx{
      char_id: nil,
      account_id: nil,
      connection_pid: nil,
      game_state: nil,
      source: {:npc, :test},
      npc_gid: nil
    }
  end

  defp character(char_id) do
    %Character{
      id: char_id,
      account_id: 100 + char_id,
      name: "Char#{char_id}",
      last_map: @map,
      last_x: 150,
      last_y: 150,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
  end
end
