defmodule Aesir.ZoneServer.Content.Npc.Woe.ControllerTest do
  use ExUnit.Case, async: false
  use Mimic

  @moduletag :capture_log

  alias Aesir.ZoneServer.Content.Npc.Woe.Controller
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Server
  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  setup do
    Registry.reload([Controller])
    on_exit(fn -> :persistent_term.erase(Registry) end)
    :ok
  end

  test "registers as WoeController and resolves the owner-event label" do
    assert [{Controller, placement}] = Registry.by_name("WoeController")
    assert is_integer(Registry.entity_id(placement))
    assert "OnEmperiumBreak" in Controller.events()
  end

  describe "OnEmperiumBreak" do
    test "a guilded killer captures the castle derived from the map" do
      stub(CastleDb, :by_map, fn "aldeg_cas03" -> {:ok, castle()} end)
      stub(CastleStore, :get, fn 2 -> %{epoch: 7} end)

      expect(Server, :capture, fn castle_id, epoch, guild_id, char_id ->
        assert castle_id == 2
        assert epoch == 7
        assert guild_id == 42
        assert char_id == 99
        {:ok, :captured}
      end)

      ctx = build_ctx(guild_id: 42, map_name: "aldeg_cas03", char_id: 99)

      assert Controller.on_event("OnEmperiumBreak", ctx) == ctx
    end

    test "a guildless killer is a no-op" do
      reject(&Server.capture/4)

      ctx = build_ctx(guild_id: nil, map_name: "aldeg_cas03", char_id: 99)

      assert Controller.on_event("OnEmperiumBreak", ctx) == ctx
    end
  end

  defp castle do
    %Castle{
      id: 2,
      map: "aldeg_cas03",
      name: "Repherion",
      client_id: 10,
      emperium: {205, 31},
      respawn: {205, 31}
    }
  end

  defp build_ctx(opts) do
    char_id = Keyword.fetch!(opts, :char_id)

    %Ctx{
      char_id: char_id,
      account_id: 100,
      connection_pid: self(),
      game_state: %PlayerState{
        character_id: char_id,
        account_id: 100,
        guild_id: Keyword.fetch!(opts, :guild_id),
        map_name: Keyword.fetch!(opts, :map_name)
      },
      source: {:npc, Controller.npc_id()}
    }
  end
end
