defmodule Aesir.ZoneServer.Gm.Commands.PvpCommandsTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Gm.Commands.PvpOff
  alias Aesir.ZoneServer.Gm.Commands.PvpOn
  alias Aesir.ZoneServer.Map.MapFlags

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = MapFlags.reload()
    :ok
  end

  defp ctx_for(map), do: %{game_state: %{map_name: map}}

  describe "names and levels" do
    test "PvpOn is pvpon at level 99" do
      assert PvpOn.name() == "pvpon"
      assert PvpOn.required_level() == 99
    end

    test "PvpOff is pvpoff at level 99" do
      assert PvpOff.name() == "pvpoff"
      assert PvpOff.required_level() == 99
    end
  end

  describe "@pvpon" do
    test "with no args enables pvp without clearing omitted modifiers" do
      :ok = MapFlags.set_runtime("prontera", :pvp_noparty, true)
      :ok = MapFlags.set_runtime("prontera", :pvp_noguild, false)

      assert PvpOn.execute([], ctx_for("prontera")) == {:ok, "PvP enabled."}
      assert MapFlags.get("prontera", :pvp) == true
      assert MapFlags.get("prontera", :pvp_noparty) == true
      refute MapFlags.get("prontera", :pvp_noguild)
    end

    test "noparty additionally sets pvp_noparty on the current map" do
      assert PvpOn.execute(["noparty"], ctx_for("prontera")) == {:ok, "PvP enabled."}
      assert MapFlags.get("prontera", :pvp) == true
      assert MapFlags.get("prontera", :pvp_noparty) == true
      refute MapFlags.get("prontera", :pvp_noguild)
    end

    test "noguild additionally sets pvp_noguild on the current map" do
      assert PvpOn.execute(["noguild"], ctx_for("prontera")) == {:ok, "PvP enabled."}
      assert MapFlags.get("prontera", :pvp) == true
      assert MapFlags.get("prontera", :pvp_noguild) == true
      refute MapFlags.get("prontera", :pvp_noparty)
    end

    test "both modifiers are set in either order" do
      for args <- [["noparty", "noguild"], ["noguild", "noparty"]] do
        map = "arena"
        assert PvpOn.execute(args, ctx_for(map)) == {:ok, "PvP enabled."}
        assert MapFlags.get(map, :pvp) == true
        assert MapFlags.get(map, :pvp_noparty) == true
        assert MapFlags.get(map, :pvp_noguild) == true

        :ok = MapFlags.clear_runtime(map, :pvp_noparty)
        :ok = MapFlags.clear_runtime(map, :pvp_noguild)
      end
    end

    test "duplicate valid args are harmless" do
      assert PvpOn.execute(["noparty", "noparty"], ctx_for("prontera")) ==
               {:ok, "PvP enabled."}

      assert MapFlags.get("prontera", :pvp) == true
      assert MapFlags.get("prontera", :pvp_noparty) == true
      refute MapFlags.get("prontera", :pvp_noguild)
    end

    test "a bogus arg returns the exact usage and changes nothing" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)
      :ok = MapFlags.set_runtime("prontera", :pvp_noparty, false)
      :ok = MapFlags.set_runtime("prontera", :pvp_noguild, true)
      before = MapFlags.flags("prontera")

      assert PvpOn.execute(["bogus"], ctx_for("prontera")) ==
               {:error, "Usage: @pvpon [noparty] [noguild]"}

      assert MapFlags.flags("prontera") == before
    end

    test "a bogus arg among valid ones validates the whole list before mutating" do
      refute MapFlags.get("prontera", :pvp)

      assert PvpOn.execute(["noparty", "bogus"], ctx_for("prontera")) ==
               {:error, "Usage: @pvpon [noparty] [noguild]"}

      refute MapFlags.get("prontera", :pvp)
      refute MapFlags.get("prontera", :pvp_noparty)
    end
  end

  describe "@pvpoff" do
    test "sets all three pvp flags false on a GM-set map" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)
      :ok = MapFlags.set_runtime("prontera", :pvp_noparty, true)
      :ok = MapFlags.set_runtime("prontera", :pvp_noguild, true)

      assert PvpOff.execute([], ctx_for("prontera")) == {:ok, "PvP disabled."}

      refute MapFlags.get("prontera", :pvp)
      refute MapFlags.get("prontera", :pvp_noparty)
      refute MapFlags.get("prontera", :pvp_noguild)
    end

    test "overlay-false beats a statically true pvp map without clearing static" do
      assert MapFlags.get("pvp_y_1-2", :pvp) == true

      assert PvpOff.execute([], ctx_for("pvp_y_1-2")) == {:ok, "PvP disabled."}

      refute MapFlags.get("pvp_y_1-2", :pvp)
      assert MapFlags.flags("pvp_y_1-2")[:pvp] == false
    end
  end
end
