defmodule Aesir.ZoneServer.PacketRegistry do
  use Aesir.Commons.Network.PacketRegistry, [
    # Client to Server packets
    Aesir.ZoneServer.Packets.CzEnter2,
    # Server to Client packets
    Aesir.ZoneServer.Packets.ZcAcceptEnter,
    Aesir.ZoneServer.Packets.ZcAid,
    Aesir.ZoneServer.Packets.ZcNotifyTime
  ]
end
