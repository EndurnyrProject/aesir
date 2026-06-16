defmodule Aesir.ZoneServer.Packets.StatusChangePacketsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.CzStatusChange
  alias Aesir.ZoneServer.Packets.ZcStatusChange

  test "CzStatusChange parses status id and amount" do
    assert {:ok, %CzStatusChange{status_id: 13, amount: 1}} =
             CzStatusChange.parse(<<0x00BB::16-little, 13::16-little, 1::8>>)
  end

  test "CzStatusChange rejects malformed input" do
    assert {:error, :invalid_packet} = CzStatusChange.parse(<<0x00BB::16-little, 13::16-little>>)
  end

  test "ZcStatusChange builds the 6-byte ack" do
    assert <<0x00BC::16-little, 13::16-little, 1::8, 6::8>> =
             ZcStatusChange.build(%ZcStatusChange{sp: 13, ok: 1, value: 6})
  end
end
