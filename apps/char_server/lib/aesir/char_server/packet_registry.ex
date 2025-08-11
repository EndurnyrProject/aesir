defmodule Aesir.CharServer.PacketRegistry do
  use Aesir.Commons.Network.PacketRegistry, [
    # Client to Server packets
    Aesir.CharServer.Packets.ChEnter,
    Aesir.CharServer.Packets.ChSelectChar,
    Aesir.CharServer.Packets.ChMakeCharV2,
    Aesir.CharServer.Packets.ChDeleteChar,
    Aesir.CharServer.Packets.ChCharlistReq,
    Aesir.CharServer.Packets.ChPing,
    Aesir.CharServer.Packets.ChReqCharDelete2,
    # Server to Client packets
    Aesir.CharServer.Packets.HcAcceptEnter,
    Aesir.CharServer.Packets.HcRefuseEnter,
    Aesir.CharServer.Packets.HcAcceptMakechar,
    Aesir.CharServer.Packets.HcRefuseMakechar,
    Aesir.CharServer.Packets.HcNotifyZonesvr,
    Aesir.CharServer.Packets.HcDeleteChar,
    Aesir.CharServer.Packets.HcCharacterList,
    Aesir.CharServer.Packets.HcCharlistNotify,
    Aesir.CharServer.Packets.HcBlockCharacter,
    Aesir.CharServer.Packets.HcSecondPasswdLogin,
    Aesir.CharServer.Packets.HcAckCharinfoPerPage,
    Aesir.CharServer.Packets.HcCharDelete2Ack
  ]
end
