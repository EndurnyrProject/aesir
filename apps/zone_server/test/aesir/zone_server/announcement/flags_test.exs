defmodule Aesir.ZoneServer.Announcement.FlagsTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias Aesir.ZoneServer.Announcement.Flags

  describe "value/1" do
    test "resolves each bc_* constant" do
      assert Flags.value("bc_all") == {:ok, 0x00}
      assert Flags.value("bc_map") == {:ok, 0x01}
      assert Flags.value("bc_area") == {:ok, 0x02}
      assert Flags.value("bc_self") == {:ok, 0x03}
      assert Flags.value("bc_pc") == {:ok, 0x00}
      assert Flags.value("bc_npc") == {:ok, 0x08}
      assert Flags.value("bc_yellow") == {:ok, 0x00}
      assert Flags.value("bc_blue") == {:ok, 0x10}
      assert Flags.value("bc_woe") == {:ok, 0x20}
    end

    test "is case-insensitive" do
      assert Flags.value("BC_SELF") == {:ok, 0x03}
    end

    test "returns :error for an unknown name" do
      assert Flags.value("bc_nope") == :error
    end
  end

  describe "decode/2" do
    test "bc_all | bc_blue with no explicit color yields blue scope :all" do
      flag = 0x00 ||| 0x10
      assert Flags.decode(flag, 0) == %{scope: :all, color: 0x0099FF, source: :pc}
    end

    test "bc_self yields scope :self, default color, source :pc" do
      assert Flags.decode(0x03, 0) == %{scope: :self, color: 0, source: :pc}
    end

    test "bc_npc source bit yields source :npc" do
      assert Flags.decode(0x08, 0) == %{scope: :all, color: 0, source: :npc}
    end

    test "a custom color_arg overrides the bc_blue bit" do
      flag = 0x00 ||| 0x10
      assert Flags.decode(flag, 0xFF0000) == %{scope: :all, color: 0xFF0000, source: :pc}
    end

    test "bc_woe with no explicit color yields the woe color" do
      flag = 0x01 ||| 0x20
      assert Flags.decode(flag, 0) == %{scope: :map, color: 0xCC0000, source: :pc}
    end

    test "unknown high scope bits fall back to :all" do
      assert Flags.decode(0x07, 0) == %{scope: :all, color: 0, source: :pc}
    end
  end

  describe "style_for/1" do
    test "maps each scope to the documented style" do
      assert Flags.style_for(:all) == :TOP
      assert Flags.style_for(:map) == :CENTER
      assert Flags.style_for(:area) == :CENTER
      assert Flags.style_for(:self) == :LOCAL
    end
  end
end
