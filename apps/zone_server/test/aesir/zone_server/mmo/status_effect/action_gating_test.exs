defmodule Aesir.ZoneServer.Mmo.StatusEffect.ActionGatingTest do
  use ExUnit.Case, async: true

  alias Aesir.StatusActionFixture
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Registry.register_module(StatusActionFixture)
    :ok
  end

  test "active status blocks items, area chat, and equipment changes" do
    assert Interpreter.can_use_item?(:player, 1000)
    assert Interpreter.can_chat?(:player, 1000)
    refute Interpreter.equip_change_blocked?(:player, 1000)

    :ok = StatusStorage.apply_status(:player, 1000, StatusActionFixture.id(), duration: 30_000)

    refute Interpreter.can_use_item?(:player, 1000)
    refute Interpreter.can_chat?(:player, 1000)
    assert Interpreter.equip_change_blocked?(:player, 1000)
  end
end
