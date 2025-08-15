defmodule Aesir.ZoneServer.PacketRegistry do
  use Aesir.Commons.Network.PacketRegistry, [
    # Client to Server packets
    Aesir.ZoneServer.Packets.CzEnter2,
    Aesir.ZoneServer.Packets.CzNotifyActorinit,
    Aesir.ZoneServer.Packets.CzRequestMove2,
    Aesir.ZoneServer.Packets.CzRequestTime,
    Aesir.ZoneServer.Packets.CzRequestTime2,
    Aesir.ZoneServer.Packets.CzReqname2,
    Aesir.ZoneServer.Packets.CzSeCashshopList,
    Aesir.ZoneServer.Packets.CzPingLive,
    # Server to Client packets
    Aesir.ZoneServer.Packets.ZcAcceptEnter,
    Aesir.ZoneServer.Packets.ZcAid,
    Aesir.ZoneServer.Packets.ZcAckReqname,
    Aesir.ZoneServer.Packets.ZcNotifyTime,
    Aesir.ZoneServer.Packets.ZcNotifyTime2,
    Aesir.ZoneServer.Packets.ZcNotifyMove,
    Aesir.ZoneServer.Packets.ZcNotifyPlayermove,
    Aesir.ZoneServer.Packets.ZcNotifyMoveStop
  ]
end
