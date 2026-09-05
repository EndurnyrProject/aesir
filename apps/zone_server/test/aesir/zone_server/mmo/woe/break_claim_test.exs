defmodule Aesir.ZoneServer.Mmo.Woe.BreakClaimTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()

    castle_id = CastleDb.all() |> hd() |> Map.fetch!(:id)
    :ok = CastleStore.set_siege(castle_id, true)
    :ok = CastleStore.set_emperium(castle_id, 1_234)

    %{castle_id: castle_id}
  end

  test "claims a live emperium by identity", %{castle_id: castle_id} do
    assert CastleStore.claim_break(castle_id, 1_234, 7) ==
             {:ok,
              %{
                owner_guild_id: 7,
                siege_active?: true,
                epoch: 1,
                emperium_unit_id: nil
              }}
  end

  test "retains an existing owner when the break has no guild credit", %{castle_id: castle_id} do
    :ok = CastleStore.hydrate(%{castle_id => 9})

    assert CastleStore.claim_break(castle_id, 1_234, nil) ==
             {:ok,
              %{
                owner_guild_id: 9,
                siege_active?: true,
                epoch: 1,
                emperium_unit_id: nil
              }}
  end

  test "keeps an unowned castle unowned when the break has no guild credit", %{
    castle_id: castle_id
  } do
    assert {:ok, state} = CastleStore.claim_break(castle_id, 1_234, nil)
    assert state.owner_guild_id == nil
  end

  test "rejects non-positive guild credit without changing the castle", %{castle_id: castle_id} do
    before_claim = CastleStore.get(castle_id)

    assert CastleStore.claim_break(castle_id, 1_234, 0) == {:error, :invalid_guild}
    assert CastleStore.claim_break(castle_id, 1_234, -1) == {:error, :invalid_guild}
    assert CastleStore.get(castle_id) == before_claim
  end

  test "allows exactly one concurrent claim and rejects old identity against a replacement", %{
    castle_id: castle_id
  } do
    results =
      1..50
      |> Task.async_stream(
        fn guild_id -> CastleStore.claim_break(castle_id, 1_234, guild_id) end,
        max_concurrency: 50,
        ordered: false,
        timeout: 10_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert [winner] = Enum.filter(results, &match?({:ok, _}, &1))
    assert {:ok, %{owner_guild_id: winner_guild_id, epoch: 1, emperium_unit_id: nil}} = winner
    assert Enum.count(results, &(&1 == {:error, :stale_emperium})) == 49

    assert CastleStore.claim_break(castle_id, 1_234, winner_guild_id) ==
             {:error, :stale_emperium}

    :ok = CastleStore.set_emperium(castle_id, 2_345)
    replacement = CastleStore.get(castle_id)

    assert CastleStore.claim_break(castle_id, 1_234, winner_guild_id) ==
             {:error, :stale_emperium}

    assert CastleStore.get(castle_id) == replacement
  end

  test "classifies inactive and unknown castles as not active", %{castle_id: castle_id} do
    :ok = CastleStore.set_siege(castle_id, false)

    assert CastleStore.claim_break(castle_id, 1_234, 7) == {:error, :not_active}
    assert CastleStore.claim_break(9_999, 1_234, 7) == {:error, :not_active}
  end

  test "rejects another or missing live emperium without changing the castle", %{
    castle_id: castle_id
  } do
    before_claim = CastleStore.get(castle_id)
    assert CastleStore.claim_break(castle_id, 2_345, 7) == {:error, :stale_emperium}
    assert CastleStore.get(castle_id) == before_claim

    :ok = CastleStore.set_emperium(castle_id, nil)
    without_emperium = CastleStore.get(castle_id)
    assert CastleStore.claim_break(castle_id, 1_234, 7) == {:error, :stale_emperium}
    assert CastleStore.get(castle_id) == without_emperium
  end
end
