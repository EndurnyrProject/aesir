defmodule Aesir.ZoneServer.Packets.CzRestartTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.CzRestart

  describe "parse/1" do
    test "parses a respawn request (type 0)" do
      assert {:ok, %CzRestart{type: 0}} = CzRestart.parse(<<0x00B2::16-little, 0::8>>)
    end

    test "parses a char-select request (type 1)" do
      assert {:ok, %CzRestart{type: 1}} = CzRestart.parse(<<0x00B2::16-little, 1::8>>)
    end

    test "rejects malformed packets" do
      assert {:error, :invalid_packet} = CzRestart.parse(<<0x00B2::16-little>>)
    end
  end
end
