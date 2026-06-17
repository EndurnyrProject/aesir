defmodule Aesir.ZoneServer.Packets.ZcNotifyGroundskillTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Packets.ZcNotifyGroundskill

  test "builds an 18-byte packet with correct layout" do
    packet = %ZcNotifyGroundskill{
      skill_id: 89,
      src_id: 2000,
      level: 10,
      x: 150,
      y: 120,
      server_tick: 5_000
    }

    built = ZcNotifyGroundskill.build(packet)

    assert byte_size(built) == 18

    assert <<0x0117::16-little, 89::16-little, 2000::32-little, 10::16-little, 150::16-little,
             120::16-little, 5_000::32-little>> = built
  end

  test "falls back to a server tick when none is given" do
    packet = %ZcNotifyGroundskill{skill_id: 89, src_id: 2000, level: 10, x: 150, y: 120}
    built = ZcNotifyGroundskill.build(packet)
    assert byte_size(built) == 18
  end
end
