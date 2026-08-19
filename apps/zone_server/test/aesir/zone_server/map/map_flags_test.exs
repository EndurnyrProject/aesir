defmodule Aesir.ZoneServer.Map.MapFlagsTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Map.MapFlags

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = MapFlags.reload()
    :ok
  end

  describe "reload/0" do
    test "loads static flags for castle maps and leaves non-castle maps empty" do
      assert MapFlags.get("aldeg_cas01", :gvg_castle) == true
      assert MapFlags.get("aldeg_cas01", :nosave) == true
      assert MapFlags.get("aldeg_cas01", :noteleport) == true
      assert MapFlags.get("aldeg_cas01", :nowarp) == true
      assert MapFlags.get("aldeg_cas01", :noreturn) == true

      refute MapFlags.get("prontera", :gvg_castle)
      refute MapFlags.get("prontera", :nosave)
      refute MapFlags.get("prontera", :noteleport)
      refute MapFlags.get("prontera", :nowarp)
      refute MapFlags.get("prontera", :noreturn)
      refute MapFlags.get("prontera", :gvg)
      refute MapFlags.get("prontera", :pvp)
    end

    test "is idempotent" do
      assert :ok = MapFlags.reload()
      assert MapFlags.get("aldeg_cas01", :gvg_castle) == true
      assert MapFlags.get("prontera", :gvg_castle) == false
    end
  end

  describe "get/2" do
    test "returns false for an unknown flag" do
      refute MapFlags.get("aldeg_cas01", :nonexistent_flag)
      refute MapFlags.get("prontera", :nonexistent_flag)
    end

    test "returns false for a known flag on a map that does not have it" do
      refute MapFlags.get("aldeg_cas01", :gvg)
      refute MapFlags.get("aldeg_cas01", :pvp)
    end
  end

  describe "set_runtime/3 and clear_runtime/2" do
    test "set_runtime then get returns true; clear_runtime reverts to static" do
      refute MapFlags.get("aldeg_cas01", :gvg)

      :ok = MapFlags.set_runtime("aldeg_cas01", :gvg, true)
      assert MapFlags.get("aldeg_cas01", :gvg) == true

      :ok = MapFlags.clear_runtime("aldeg_cas01", :gvg)
      refute MapFlags.get("aldeg_cas01", :gvg)
    end

    test "overlay precedence: static true + overlay false -> get returns false" do
      assert MapFlags.get("aldeg_cas01", :gvg_castle) == true

      :ok = MapFlags.set_runtime("aldeg_cas01", :gvg_castle, false)
      refute MapFlags.get("aldeg_cas01", :gvg_castle)

      :ok = MapFlags.clear_runtime("aldeg_cas01", :gvg_castle)
      assert MapFlags.get("aldeg_cas01", :gvg_castle) == true
    end

    test "unknown flags are ignored: set_runtime/clear_runtime are no-ops" do
      assert :ok = MapFlags.set_runtime("aldeg_cas01", :flying, true)
      refute MapFlags.get("aldeg_cas01", :flying)
      assert MapFlags.get("aldeg_cas01", :gvg_castle) == true

      assert :ok = MapFlags.clear_runtime("aldeg_cas01", :flying)
      refute MapFlags.get("aldeg_cas01", :flying)
    end

    test "pvp_noparty/pvp_noguild roundtrip through set_runtime/get/clear_runtime to static false" do
      for flag <- [:pvp_noparty, :pvp_noguild] do
        refute MapFlags.get("prontera", flag)

        :ok = MapFlags.set_runtime("prontera", flag, true)
        assert MapFlags.get("prontera", flag) == true

        :ok = MapFlags.clear_runtime("prontera", flag)
        refute MapFlags.get("prontera", flag)
      end
    end
  end

  describe "flags/1" do
    test "returns merged view of static flags and true runtime overlays" do
      flags = MapFlags.flags("aldeg_cas01")

      assert flags[:gvg_castle] == true
      assert flags[:nosave] == true
      assert flags[:noteleport] == true
      assert flags[:nowarp] == true
      assert flags[:noreturn] == true
      refute Map.has_key?(flags, :gvg)
    end

    test "true runtime entries appear in the merged view" do
      :ok = MapFlags.set_runtime("aldeg_cas01", :gvg, true)
      flags = MapFlags.flags("aldeg_cas01")
      assert flags[:gvg] == true
    end

    test "agrees with get/2 when an overlay shadows a static flag" do
      assert MapFlags.get("aldeg_cas01", :gvg_castle) == true

      :ok = MapFlags.set_runtime("aldeg_cas01", :gvg_castle, false)

      refute MapFlags.get("aldeg_cas01", :gvg_castle)
      assert MapFlags.flags("aldeg_cas01")[:gvg_castle] == false
    end

    test "non-castle map has no flags" do
      assert MapFlags.flags("prontera") == %{}
    end
  end
end
