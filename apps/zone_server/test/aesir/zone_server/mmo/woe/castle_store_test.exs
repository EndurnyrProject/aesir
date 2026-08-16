defmodule Aesir.ZoneServer.Mmo.Woe.CastleStoreTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    :ok
  end

  defp first_castle_id do
    CastleDb.all() |> hd() |> Map.fetch!(:id)
  end

  describe "init/0" do
    test "seeds one neutral row per castle" do
      assert :ets.info(EtsTable.table_for(:castle_states), :size) == length(CastleDb.all())

      assert CastleStore.get(first_castle_id()) == %{
               owner_guild_id: nil,
               siege_active?: false,
               epoch: 0,
               emperium_unit_id: nil
             }
    end

    test "re-running does not clobber hydrated owners" do
      [castle_a, castle_b | _] = CastleDb.all()

      :ok = CastleStore.hydrate(%{castle_a.id => 10, castle_b.id => 20})
      :ok = CastleStore.init()

      assert CastleStore.owner(castle_a.id) == 10
      assert CastleStore.owner(castle_b.id) == 20
    end
  end

  describe "hydrate/1" do
    test "sets owners from a castle_id => guild_id map" do
      [castle_a, castle_b | _] = CastleDb.all()

      :ok = CastleStore.hydrate(%{castle_a.id => 10, castle_b.id => 20})

      assert CastleStore.owner(castle_a.id) == 10
      assert CastleStore.owner(castle_b.id) == 20
    end
  end

  describe "get/1 and owner/1" do
    test "return neutral defaults for an unknown castle" do
      assert CastleStore.get(9_999) == %{
               owner_guild_id: nil,
               siege_active?: false,
               epoch: 0,
               emperium_unit_id: nil
             }

      assert CastleStore.owner(9_999) == nil
    end
  end

  describe "capture/3" do
    test "succeeds exactly once under concurrency, bumping the epoch and setting the winner" do
      castle_id = first_castle_id()
      :ok = CastleStore.set_siege(castle_id, true)

      results =
        1..50
        |> Task.async_stream(
          fn guild_id -> {guild_id, CastleStore.capture(castle_id, 0, guild_id)} end,
          max_concurrency: 50,
          ordered: false,
          timeout: 10_000
        )
        |> Enum.map(fn {:ok, pair} -> pair end)

      winners = Enum.filter(results, fn {_guild_id, result} -> match?({:ok, _}, result) end)
      assert [{winner_guild, {:ok, 1}}] = winners

      losers = Enum.filter(results, fn {_guild_id, result} -> match?({:error, _}, result) end)
      assert length(losers) == 49
      assert Enum.all?(losers, fn {_guild_id, result} -> result == {:error, :stale_epoch} end)

      assert CastleStore.owner(castle_id) == winner_guild
      assert CastleStore.get(castle_id).epoch == 1
    end

    test "is refused when the siege is not active" do
      castle_id = first_castle_id()

      assert CastleStore.capture(castle_id, 0, 7) == {:error, :not_active}
    end

    test "is refused for an unknown castle" do
      assert CastleStore.capture(9_999, 0, 7) == {:error, :not_active}
    end

    test "is refused when the expected epoch is stale" do
      castle_id = first_castle_id()
      :ok = CastleStore.set_siege(castle_id, true)

      assert CastleStore.capture(castle_id, 5, 7) == {:error, :stale_epoch}
    end

    test "success sets the owner, bumps the epoch, and preserves the emperium unit" do
      castle_id = first_castle_id()
      :ok = CastleStore.set_siege(castle_id, true)
      :ok = CastleStore.set_emperium(castle_id, 1234)

      assert CastleStore.capture(castle_id, 0, 7) == {:ok, 1}

      assert CastleStore.get(castle_id) == %{
               owner_guild_id: 7,
               siege_active?: true,
               epoch: 1,
               emperium_unit_id: 1234
             }
    end

    test "a later round with the bumped epoch can capture again" do
      castle_id = first_castle_id()
      :ok = CastleStore.set_siege(castle_id, true)

      assert CastleStore.capture(castle_id, 0, 7) == {:ok, 1}
      assert CastleStore.capture(castle_id, 1, 8) == {:ok, 2}

      assert CastleStore.owner(castle_id) == 8
      assert CastleStore.get(castle_id).epoch == 2
    end
  end

  describe "set_siege/2 and set_emperium/2" do
    test "toggle the siege flag" do
      castle_id = first_castle_id()
      refute CastleStore.get(castle_id).siege_active?

      :ok = CastleStore.set_siege(castle_id, true)
      assert CastleStore.get(castle_id).siege_active?

      :ok = CastleStore.set_siege(castle_id, false)
      refute CastleStore.get(castle_id).siege_active?
    end

    test "record and clear the emperium unit" do
      castle_id = first_castle_id()

      :ok = CastleStore.set_emperium(castle_id, 4321)
      assert CastleStore.get(castle_id).emperium_unit_id == 4321

      :ok = CastleStore.set_emperium(castle_id, nil)
      assert CastleStore.get(castle_id).emperium_unit_id == nil
    end
  end
end
