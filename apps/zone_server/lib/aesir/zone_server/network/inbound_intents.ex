defmodule Aesir.ZoneServer.Network.InboundIntents do
  @moduledoc """
  Allowlist of client -> server `Aesir.Net.*` messages the zone accepts once a
  player session is bound.

  The wire `Envelope` `oneof` lets a client place ANY body in a frame, including
  server-authoritative messages it should only ever receive (`DamageDealt`,
  `UnitHp`, `Snapshot`, `Knockback`, ...). Inbound routing is purely structural
  pattern matching, so this allowlist is the boundary that drops forged
  authoritative messages before they reach the player session.

  This is the inbound counterpart to the outbound table in
  `Aesir.ZoneServer.Network.MessageRouter`; the two sets are disjoint by design.
  Control/handshake messages (`Hello`, `SessionAuth`, `TimeSync`) are matched by
  dedicated clauses in `Aesir.ZoneServer` and never reach this check.
  """

  @client_intents MapSet.new([
                    Aesir.Net.ActionRequest,
                    Aesir.Net.ChatRequest,
                    Aesir.Net.EquipItem,
                    Aesir.Net.GroundSkillCast,
                    Aesir.Net.LearnSkill,
                    Aesir.Net.MapLoaded,
                    Aesir.Net.MoveRequest,
                    Aesir.Net.NameRequest,
                    Aesir.Net.NpcInteract,
                    Aesir.Net.NpcTalk,
                    Aesir.Net.Respawn,
                    Aesir.Net.SkillCast,
                    Aesir.Net.StatUp,
                    Aesir.Net.UnequipItem,
                    Aesir.Net.UseItem,
                    Aesir.Net.VendingCloseRequest,
                    Aesir.Net.VendingListRequest,
                    Aesir.Net.VendingOpenRequest,
                    Aesir.Net.VendingPurchaseRequest
                  ])

  @doc """
  Returns true when `message` is a client intent the zone accepts from a player.
  """
  @spec client_intent?(struct()) :: boolean()
  def client_intent?(%module{}), do: MapSet.member?(@client_intents, module)
  def client_intent?(_), do: false
end
