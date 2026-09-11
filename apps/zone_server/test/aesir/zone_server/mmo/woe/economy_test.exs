defmodule Aesir.ZoneServer.Mmo.Woe.EconomyTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Economy
  alias Aesir.ZoneServer.Mmo.Woe.Persistence

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    stub(Persistence, :persist_economy, fn _castle_id, _state -> :ok end)
    :ok
  end

  defp first_castle_id, do: CastleDb.all() |> hd() |> Map.fetch!(:id)

  describe "invest_cost/3" do
    test "economy tiers step every five levels" do
      assert Economy.invest_cost(:economy, 0, 0) == 5_000
      assert Economy.invest_cost(:economy, 5, 0) == 5_000
      assert Economy.invest_cost(:economy, 6, 0) == 10_000
      assert Economy.invest_cost(:economy, 10, 0) == 10_000
      assert Economy.invest_cost(:economy, 11, 0) == 20_000
      assert Economy.invest_cost(:economy, 95, 0) == 860_000
      assert Economy.invest_cost(:economy, 96, 0) == 955_000
      assert Economy.invest_cost(:economy, 100, 0) == 955_000
    end

    test "defense tiers step every five levels" do
      assert Economy.invest_cost(:defense, 0, 0) == 10_000
      assert Economy.invest_cost(:defense, 5, 0) == 10_000
      assert Economy.invest_cost(:defense, 6, 0) == 20_000
      assert Economy.invest_cost(:defense, 10, 0) == 20_000
      assert Economy.invest_cost(:defense, 11, 0) == 40_000
      assert Economy.invest_cost(:defense, 95, 0) == 1_720_000
      assert Economy.invest_cost(:defense, 96, 0) == 1_910_000
      assert Economy.invest_cost(:defense, 100, 0) == 1_910_000
    end

    test "quadruples once already invested today" do
      assert Economy.invest_cost(:economy, 0, 1) == 20_000
      assert Economy.invest_cost(:defense, 0, 1) == 40_000
    end
  end

  describe "invest/3" do
    test "returns :not_owner when the guild does not hold the castle" do
      castle_id = first_castle_id()

      :ok =
        CastleStore.hydrate(%{
          castle_id => %{
            guild_id: 1,
            economy: 0,
            defense: 0,
            invested_economy: 0,
            invested_defense: 0
          }
        })

      assert Economy.invest(castle_id, :economy, 2) == {:error, :not_owner}
    end

    test "returns :maxed when the track is already at level 100, even for a non-owner" do
      castle_id = first_castle_id()

      :ok =
        CastleStore.hydrate(%{
          castle_id => %{
            guild_id: 1,
            economy: 100,
            defense: 0,
            invested_economy: 0,
            invested_defense: 0
          }
        })

      assert Economy.invest(castle_id, :economy, 1) == {:error, :maxed}
    end

    test "returns :daily_limit once two investments have already been made today" do
      castle_id = first_castle_id()

      :ok =
        CastleStore.hydrate(%{
          castle_id => %{
            guild_id: 1,
            economy: 10,
            defense: 0,
            invested_economy: 2,
            invested_defense: 0
          }
        })

      assert Economy.invest(castle_id, :economy, 1) == {:error, :daily_limit}
    end

    test "on success, charges the pre-increment cost and increments the counter in the store" do
      castle_id = first_castle_id()

      :ok =
        CastleStore.hydrate(%{
          castle_id => %{
            guild_id: 1,
            economy: 6,
            defense: 0,
            invested_economy: 1,
            invested_defense: 0
          }
        })

      assert Economy.invest(castle_id, :economy, 1) == {:ok, 40_000}

      assert CastleStore.economy(castle_id) == %{
               economy: 6,
               defense: 0,
               invested_economy: 2,
               invested_defense: 0
             }
    end
  end

  describe "mature/3" do
    test "adds today's investments to economy and defense" do
      state = %{economy: 10, defense: 20, invested_economy: 1, invested_defense: 1}

      assert Economy.mature(state, false, fn -> 1 end) == %{
               economy: 11,
               defense: 21,
               invested_economy: 0,
               invested_defense: 0
             }
    end

    test "caps economy and defense at 100" do
      state = %{economy: 99, defense: 99, invested_economy: 2, invested_defense: 2}

      assert Economy.mature(state, false, fn -> 1 end) == %{
               economy: 100,
               defense: 100,
               invested_economy: 0,
               invested_defense: 0
             }
    end

    test "applies the bonus point only when all three conditions hold" do
      invested = %{economy: 10, defense: 0, invested_economy: 1, invested_defense: 0}
      not_invested = %{economy: 10, defense: 0, invested_economy: 0, invested_defense: 0}

      assert Economy.mature(invested, true, fn -> 2 end).economy == 12
      assert Economy.mature(invested, true, fn -> 1 end).economy == 11
      assert Economy.mature(invested, false, fn -> 2 end).economy == 11
      assert Economy.mature(not_invested, true, fn -> 2 end).economy == 10
    end
  end

  describe "mature_all/0" do
    test "applies maturation to owned castles and leaves unowned castles untouched" do
      [owned, unowned | _] = CastleDb.all()

      :ok =
        CastleStore.hydrate(%{
          owned.id => %{
            guild_id: 1,
            economy: 10,
            defense: 5,
            invested_economy: 1,
            invested_defense: 1
          }
        })

      stub(GuildManager, :get, fn 1 -> {:error, :not_found} end)

      assert Economy.mature_all() == :ok

      assert CastleStore.economy(owned.id) == %{
               economy: 11,
               defense: 6,
               invested_economy: 0,
               invested_defense: 0
             }

      assert CastleStore.economy(unowned.id) == %{
               economy: 0,
               defense: 0,
               invested_economy: 0,
               invested_defense: 0
             }
    end
  end

  describe "conquest_penalty/1" do
    test "drops both tracks by five, floored at zero, and clears counters" do
      state = %{economy: 3, defense: 10, invested_economy: 2, invested_defense: 1}

      assert Economy.conquest_penalty(state) == %{
               economy: 0,
               defense: 5,
               invested_economy: 0,
               invested_defense: 0
             }
    end
  end

  describe "apply_conquest_penalty/1" do
    test "writes the penalized state to the castle store" do
      castle_id = first_castle_id()

      :ok =
        CastleStore.hydrate(%{
          castle_id => %{
            guild_id: 1,
            economy: 10,
            defense: 3,
            invested_economy: 2,
            invested_defense: 1
          }
        })

      assert Economy.apply_conquest_penalty(castle_id) == :ok

      assert CastleStore.economy(castle_id) == %{
               economy: 5,
               defense: 0,
               invested_economy: 0,
               invested_defense: 0
             }
    end
  end

  describe "emperium_summon_opts/2" do
    test "scales HP by mode and derives a flat DEF/MDEF bonus from defense" do
      {:ok, mob} = Mobs.by_id(1288)

      assert Economy.emperium_summon_opts(100, :renewal) == [
               hp_override: mob.hp + 1_000,
               stat_bonus: %{def: 34, mdef: 34}
             ]

      assert Economy.emperium_summon_opts(100, :pre_renewal) == [
               hp_override: mob.hp + 100_000,
               stat_bonus: %{def: 34, mdef: 34}
             ]
    end
  end
end
