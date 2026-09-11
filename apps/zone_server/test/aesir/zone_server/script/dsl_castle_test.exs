defmodule Aesir.ZoneServer.Script.DslCastleTest do
  @moduledoc """
  Covers the Task 9 castle DSL surface: castle identity/ownership/economy
  reads (`castle_at/1`, `castle_name/2`, `castle_owner/2`, `castle_economy/2`,
  `castle_invest_cost/3`), guild leadership (`is_guild_leader/2`), and the
  investment effect (`castle_invest/3`) which routes through
  `Economy.invest/3` and halts the ctx on rejection.
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Economy
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    stub(Persistence, :persist_economy, fn _castle_id, _state -> :ok end)
    :ok
  end

  defp first_castle, do: CastleDb.all() |> hd()

  defp row(guild_id, overrides \\ %{}) do
    Map.merge(
      %{guild_id: guild_id, economy: 0, defense: 0, invested_economy: 0, invested_defense: 0},
      overrides
    )
  end

  describe "castle_at/1" do
    test "returns the castle id on a castle map" do
      castle = first_castle()
      ctx = build_ctx(map_name: castle.map)

      assert Dsl.castle_at(ctx) == castle.id
    end

    test "returns nil on a non-castle map" do
      ctx = build_ctx(map_name: "prontera")

      assert Dsl.castle_at(ctx) == nil
    end

    test "raises on a detached ctx" do
      assert_raise ArgumentError, fn -> Dsl.castle_at(detached_ctx()) end
    end
  end

  describe "castle_name/2" do
    test "returns the castle's display name" do
      castle = first_castle()

      assert Dsl.castle_name(build_ctx(), castle.id) == castle.name
    end
  end

  describe "castle_owner/2" do
    test "nil when unowned" do
      castle = first_castle()

      assert Dsl.castle_owner(build_ctx(), castle.id) == nil
    end

    test "the owning guild id once hydrated" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(7)})

      assert Dsl.castle_owner(build_ctx(), castle.id) == 7
    end
  end

  describe "castle_economy/2" do
    test "returns the castle's economy state" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(7, %{economy: 12, defense: 3})})

      assert Dsl.castle_economy(build_ctx(), castle.id) == %{
               economy: 12,
               defense: 3,
               invested_economy: 0,
               invested_defense: 0
             }
    end
  end

  describe "castle_invest_cost/3" do
    test "matches Economy.invest_cost/3 for the castle's current level" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(7, %{economy: 6, invested_economy: 1})})

      assert Dsl.castle_invest_cost(build_ctx(), castle.id, :economy) ==
               Economy.invest_cost(:economy, 6, 1)
    end
  end

  describe "is_guild_leader/2" do
    test "true for the guild's master char id" do
      stub(GuildManager, :get, fn 5 ->
        {:ok, %GuildState{guild_id: 5, name: "G", master_char_id: 42}}
      end)

      assert Dsl.is_guild_leader(build_ctx(char_id: 42), 5)
    end

    test "false for a non-master char id" do
      stub(GuildManager, :get, fn 5 ->
        {:ok, %GuildState{guild_id: 5, name: "G", master_char_id: 42}}
      end)

      refute Dsl.is_guild_leader(build_ctx(char_id: 43), 5)
    end

    test "false when the guild is unknown" do
      stub(GuildManager, :get, fn 999 -> {:error, :not_found} end)

      refute Dsl.is_guild_leader(build_ctx(char_id: 42), 999)
    end
  end

  describe "castle_invest/3" do
    test "halts with :not_owner for a non-owner" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      ctx = build_ctx(guild_id: 2)

      result = Dsl.castle_invest(ctx, castle.id, :economy)

      assert result.status == {:error, :not_owner}
    end

    test "leaves the ctx status ok and increments the counter for the owner" do
      castle = first_castle()
      :ok = CastleStore.hydrate(%{castle.id => row(1)})
      ctx = build_ctx(guild_id: 1)

      result = Dsl.castle_invest(ctx, castle.id, :economy)

      assert result.status == :ok
      assert CastleStore.economy(castle.id).invested_economy == 1
    end

    test "halts :no_player on a detached ctx" do
      castle = first_castle()

      result = Dsl.castle_invest(detached_ctx(), castle.id, :economy)

      assert result.status == {:error, :no_player}
    end
  end

  defp build_ctx(opts \\ []) do
    %Ctx{
      char_id: Keyword.get(opts, :char_id, 1),
      account_id: 100,
      connection_pid: self(),
      game_state: build_game_state(opts),
      source: {:npc, :test_npc}
    }
  end

  defp detached_ctx do
    %Ctx{
      char_id: nil,
      account_id: nil,
      connection_pid: nil,
      game_state: nil,
      source: {:npc, :test_npc}
    }
  end

  defp build_game_state(opts) do
    %PlayerState{
      character_id: Keyword.get(opts, :char_id, 1),
      account_id: 100,
      map_name: Keyword.get(opts, :map_name, "prontera"),
      guild_id: Keyword.get(opts, :guild_id, 0)
    }
  end
end
