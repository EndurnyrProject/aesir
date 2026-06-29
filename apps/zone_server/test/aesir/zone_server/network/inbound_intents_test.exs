defmodule Aesir.ZoneServer.Network.InboundIntentsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Network.InboundIntents

  test "accepts client -> server intent messages" do
    assert InboundIntents.client_intent?(%Aesir.Net.ActionRequest{})
    assert InboundIntents.client_intent?(%Aesir.Net.SkillCast{})
    assert InboundIntents.client_intent?(%Aesir.Net.GroundSkillCast{})
    assert InboundIntents.client_intent?(%Aesir.Net.MoveRequest{})
    assert InboundIntents.client_intent?(%Aesir.Net.NpcTalk{})
    assert InboundIntents.client_intent?(%Aesir.Net.NpcBuyRequest{})
    assert InboundIntents.client_intent?(%Aesir.Net.NpcSellRequest{})
    assert InboundIntents.client_intent?(%Aesir.Net.VendingOpenRequest{})
    assert InboundIntents.client_intent?(%Aesir.Net.VendingCloseRequest{})
    assert InboundIntents.client_intent?(%Aesir.Net.VendingListRequest{})
    assert InboundIntents.client_intent?(%Aesir.Net.VendingPurchaseRequest{})
  end

  test "rejects server-authoritative / server -> client messages" do
    refute InboundIntents.client_intent?(%Aesir.Net.DamageDealt{})
    refute InboundIntents.client_intent?(%Aesir.Net.SkillDamage{})
    refute InboundIntents.client_intent?(%Aesir.Net.UnitHp{})
    refute InboundIntents.client_intent?(%Aesir.Net.Snapshot{})
    refute InboundIntents.client_intent?(%Aesir.Net.Knockback{})
    refute InboundIntents.client_intent?(%Aesir.Net.VendingList{})
    refute InboundIntents.client_intent?(%Aesir.Net.VendingBoardShown{})
    refute InboundIntents.client_intent?(%Aesir.Net.VendingSaleReport{})
  end

  test "rejects non-struct input" do
    refute InboundIntents.client_intent?(:not_a_struct)
    refute InboundIntents.client_intent?(%{})
  end
end
