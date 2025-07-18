defmodule Aesir.CharServer.PacketRegistry do
  use Aesir.Commons.Network.PacketRegistry, [
    Aesir.CharServer.Packets.ChEnter,
    Aesir.CharServer.Packets.ChSelectChar,
    Aesir.CharServer.Packets.ChMakeChar,
    Aesir.CharServer.Packets.ChDeleteChar,
    Aesir.CharServer.Packets.HcAcceptEnter,
    Aesir.CharServer.Packets.HcRefuseEnter,
    Aesir.CharServer.Packets.HcAcceptMakechar,
    Aesir.CharServer.Packets.HcRefuseMakechar,
    Aesir.CharServer.Packets.HcNotifyZonesvr,
    Aesir.CharServer.Packets.HcDeleteChar
  ]
end
