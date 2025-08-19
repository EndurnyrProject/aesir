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
    Aesir.ZoneServer.Packets.ZcNotifyPlayermove,
    Aesir.ZoneServer.Packets.ZcNotifyMoveStop,
    Aesir.ZoneServer.Packets.ZcNotifyMoveentry,
    Aesir.ZoneServer.Packets.ZcNotifyNewentry,
    Aesir.ZoneServer.Packets.ZcNotifyStandentry,
    Aesir.ZoneServer.Packets.ZcNotifyVanish,
    Aesir.ZoneServer.Packets.ZcParChange,
    Aesir.ZoneServer.Packets.ZcLongparChange
  ]
end
