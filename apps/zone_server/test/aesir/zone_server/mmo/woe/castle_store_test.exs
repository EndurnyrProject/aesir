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

  defp row(guild_id, overrides \\ %{}) do
    Map.merge(
      %{guild_id: guild_id, economy: 0, defense: 0, invested_economy: 0, invested_defense: 0},
      overrides
    )
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

    test "seeds zero economy state per castle" do
      assert CastleStore.economy(first_castle_id()) == %{
               economy: 0,
               defense: 0,
               invested_economy: 0,
               invested_defense: 0
             }
    end

    test "seeds an empty guardian list per castle" do
      assert CastleStore.guardians(first_castle_id()) == []
    end

    test "the castle_guardians ETS table exists" do
      refute :ets.info(EtsTable.table_for(:castle_guardians)) == :undefined
    end

    test "re-running does not clobber hydrated owners" do
      [castle_a, castle_b | _] = CastleDb.all()

      :ok = CastleStore.hydrate(%{castle_a.id => row(10), castle_b.id => row(20)})
      :ok = CastleStore.init()

      assert CastleStore.owner(castle_a.id) == 10
      assert CastleStore.owner(castle_b.id) == 20
    end
  end

  describe "hydrate/1" do
    test "sets owner and all four economy fields from a full-row map" do
      [castle_a, castle_b | _] = CastleDb.all()

      :ok =
        CastleStore.hydrate(%{
          castle_a.id =>
            row(10, %{economy: 40, defense: 25, invested_economy: 1, invested_defense: 2}),
          castle_b.id => row(20)
        })

      assert CastleStore.owner(castle_a.id) == 10

      assert CastleStore.economy(castle_a.id) == %{
               economy: 40,
               defense: 25,
               invested_economy: 1,
               invested_defense: 2
             }

      assert CastleStore.owner(castle_b.id) == 20

      assert CastleStore.economy(castle_b.id) == %{
               economy: 0,
               defense: 0,
               invested_economy: 0,
               invested_defense: 0
             }
    end

    test "sets guardians from a row with a guardians key, and leaves [] without one" do
      [castle_a, castle_b | _] = CastleDb.all()

      :ok =
        CastleStore.hydrate(%{
          castle_a.id => row(10, %{guardians: [2, 5]}),
          castle_b.id => row(20)
        })

      assert CastleStore.guardians(castle_a.id) == [2, 5]
      assert CastleStore.guardians(castle_b.id) == []
    end
  end

  describe "guardians/1 and put_guardians/2" do
    test "put_guardians/2 replaces the list, sorted and deduplicated" do
      castle_id = first_castle_id()

      :ok = CastleStore.put_guardians(castle_id, [3, 1, 1, 2])

      assert CastleStore.guardians(castle_id) == [1, 2, 3]
    end

    test "put_guardians/2 leaves owner, siege, epoch, emperium, and economy untouched" do
      castle_id = first_castle_id()

      :ok = CastleStore.hydrate(%{castle_id => row(10, %{economy: 40, defense: 25})})
      :ok = CastleStore.set_siege(castle_id, true)
      :ok = CastleStore.set_emperium(castle_id, 999)

      :ok = CastleStore.put_guardians(castle_id, [4])

      assert CastleStore.get(castle_id) == %{
               owner_guild_id: 10,
               siege_active?: true,
               epoch: 0,
               emperium_unit_id: 999
             }

      assert CastleStore.economy(castle_id) == %{
               economy: 40,
               defense: 25,
               invested_economy: 0,
               invested_defense: 0
             }
    end

    test "returns [] for an unknown castle" do
      assert CastleStore.guardians(9_999) == []
    end
  end

  describe "put_economy/2" do
    test "replaces economy state without touching owner, siege, epoch, or emperium" do
      castle_id = first_castle_id()

      :ok = CastleStore.hydrate(%{castle_id => row(10)})
      :ok = CastleStore.set_siege(castle_id, true)
      :ok = CastleStore.set_emperium(castle_id, 999)

      :ok =
        CastleStore.put_economy(castle_id, %{
          economy: 60,
          defense: 30,
          invested_economy: 2,
          invested_defense: 1
        })

      assert CastleStore.economy(castle_id) == %{
               economy: 60,
               defense: 30,
               invested_economy: 2,
               invested_defense: 1
             }

      assert CastleStore.get(castle_id) == %{
               owner_guild_id: 10,
               siege_active?: true,
               epoch: 0,
               emperium_unit_id: 999
             }
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

  describe "set_siege/2 and set_emperium/2" do
    test "toggle the siege flag" do
      castle_id = first_castle_id()
      refute CastleStore.get(castle_id).siege_active?

      :ok = CastleStore.set_siege(castle_id, true)
      assert CastleStore.get(castle_id).siege_active?

      :ok = CastleStore.set_siege(castle_id, false)
      refute CastleStore.get(castle_id).siege_active?
      assert CastleStore.get(castle_id).epoch == 1
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
