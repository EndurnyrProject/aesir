defmodule Aesir.AccountServer.PacketRegistry do
  use Aesir.Network.PacketRegistry, [
    Aesir.AccountServer.Packets.AcAcceptLogin,
    Aesir.AccountServer.Packets.AcAckHash,
    Aesir.AccountServer.Packets.AcRefuseLogin,
    Aesir.AccountServer.Packets.CaExeHashcheck,
    Aesir.AccountServer.Packets.CaLogin,
    Aesir.AccountServer.Packets.CaReqHash,
    Aesir.AccountServer.Packets.CtAuth,
    Aesir.AccountServer.Packets.TcResult
  ]
end
