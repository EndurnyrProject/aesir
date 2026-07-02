defmodule Aesir.ZoneServer.Npc.VerifierTest do
  use ExUnit.Case, async: true
  import Mimic
  import ExUnit.CaptureLog

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
    test "returns :ok for unique cells (walkability is not required)" do
      entries = [
        {ModA, placement(x: 150, y: 150)},
        {ModB, placement(x: 151, y: 150)}
      ]

      assert :ok = Verifier.verify(entries)
    end

    test "flags two NPCs sharing one cell" do
      entries = [
        {ModA, placement(x: 150, y: 150)},
        {ModB, placement(x: 150, y: 150)}
      ]

      assert {:error, errors} = Verifier.verify(entries)
      assert Enum.any?(errors, &match?({:cell_collision, {"prontera", 150, 150}, _mods}, &1))
    end
  end

  describe "verify!/1" do
    test "returns :ok for unique cells on loaded maps" do
      stub(MapCache, :exists?, fn _ -> true end)

      assert :ok = Verifier.verify!([{ModA, placement(x: 150, y: 150)}])
    end

    test "warns but does not raise for a placement on an unloaded map" do
      stub(MapCache, :exists?, fn _ -> false end)

      log =
        capture_log(fn ->
          assert :ok = Verifier.verify!([{ModA, placement(map: "morocc", x: 208, y: 90)}])
        end)

      assert log =~ "not loaded"
    end

    test "warns but does not raise at boot on a cell collision" do
      stub(MapCache, :exists?, fn _ -> true end)

      log =
        capture_log(fn ->
          assert :ok =
                   Verifier.verify!([
                     {ModA, placement(x: 150, y: 150)},
                     {ModB, placement(x: 150, y: 150)}
                   ])
        end)

      assert log =~ "cell collision"
    end
  end
end
