defmodule Aesir.ZoneServer.Content.Npc.Woe.FlagOwnerTest do
  @moduledoc """
  Covers the Task 5 `FlagOwner` helpers shared by `OutsideFlag` and
  `InsideFlag`: parsing the castle map out of a flag's unique name and
  resolving the owning guild id.
  """

  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Content.Npc.Woe.FlagOwner
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Npc.Placement

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    :ok
  end

  defp placement(unique_name) do
    struct!(Placement, map: "alde_gld", x: 1, y: 1, sprite: 722, unique_name: unique_name)
  end

  defp row(guild_id, overrides \\ %{}) do
    Map.merge(
      %{
        guild_id: guild_id,
        economy: 0,
        defense: 0,
        invested_economy: 0,
        invested_defense: 0,
        guardians: []
      },
      overrides
    )
  end

  describe "castle_map/1" do
    test "splits name#map#index into the castle map" do
      assert FlagOwner.castle_map(placement("Neuschwanstein#aldeg_cas01#3")) ==
               {:ok, "aldeg_cas01"}
    end

    test "returns :error for a unique name with no # separators" do
      assert FlagOwner.castle_map(placement("Neuschwanstein")) == :error
    end

    test "accepts a non-numeric third segment (the out/in disambiguator)" do
      assert FlagOwner.castle_map(placement("Neuschwanstein#aldeg_cas01#out3")) ==
               {:ok, "aldeg_cas01"}

      assert FlagOwner.castle_map(placement("Neuschwanstein#aldeg_cas01#in12")) ==
               {:ok, "aldeg_cas01"}
    end
  end

  describe "guild_id/1" do
    test "returns the owner id when the castle is owned" do
      castle = CastleDb.all() |> hd()
      :ok = CastleStore.hydrate(%{castle.id => row(5)})
      placement = placement("Whatever##{castle.map}#0")

      assert FlagOwner.guild_id(placement) == 5
    end

    test "returns 0 when the castle is unowned" do
      castle = CastleDb.all() |> hd()
      placement = placement("Whatever##{castle.map}#0")

      assert FlagOwner.guild_id(placement) == 0
    end

    test "returns 0 for an unparseable unique name" do
      assert FlagOwner.guild_id(placement("Whatever")) == 0
    end
  end
end
