defmodule Aesir.ZoneServer.Npc.VerifierTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Verifier

  setup :verify_on_exit!

  defp placement(overrides) do
    struct!(
      Placement,
      Keyword.merge([map: "prontera", x: 150, y: 150, sprite: 58, name: "T"], overrides)
    )
  end

  describe "verify/1" do
    test "returns :ok when every cell is walkable and unique" do
      stub(MapCache, :walkable?, fn _, _, _ -> true end)

      entries = [
        {ModA, placement(x: 150, y: 150)},
        {ModB, placement(x: 151, y: 150)}
      ]

      assert :ok = Verifier.verify(entries)
    end

    test "flags a non-walkable spawn cell" do
      stub(MapCache, :walkable?, fn "prontera", 150, 150 -> false end)

      assert {:error, errors} = Verifier.verify([{ModA, placement(x: 150, y: 150)}])
      assert Enum.any?(errors, &match?({:non_walkable, ModA, {"prontera", 150, 150}}, &1))
    end

    test "flags two NPCs sharing one cell" do
      stub(MapCache, :walkable?, fn _, _, _ -> true end)

      entries = [
        {ModA, placement(x: 150, y: 150)},
        {ModB, placement(x: 150, y: 150)}
      ]

      assert {:error, errors} = Verifier.verify(entries)
      assert Enum.any?(errors, &match?({:cell_collision, {"prontera", 150, 150}, _mods}, &1))
    end
  end

  describe "verify!/1" do
    test "returns :ok when every cell is walkable and unique" do
      stub(MapCache, :walkable?, fn _, _, _ -> true end)

      assert :ok = Verifier.verify!([{ModA, placement(x: 150, y: 150)}])
    end

    test "raises ArgumentError at boot when a cell is non-walkable" do
      stub(MapCache, :walkable?, fn _, _, _ -> false end)

      assert_raise ArgumentError, fn ->
        Verifier.verify!([{ModA, placement(x: 150, y: 150)}])
      end
    end
  end
end
