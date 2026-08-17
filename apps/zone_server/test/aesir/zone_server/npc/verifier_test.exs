defmodule Aesir.ZoneServer.Npc.VerifierTest do
  use ExUnit.Case, async: true
  import Mimic
  import ExUnit.CaptureLog

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

    test "allows two NPCs on one cell when their unique_names differ" do
      entries = [
        {ModA, placement(x: 150, y: 150, unique_name: "Guide#a")},
        {ModB, placement(x: 150, y: 150, unique_name: "Controller#b")}
      ]

      assert :ok = Verifier.verify(entries)
    end

    test "flags two NPCs sharing a cell and unique_name" do
      entries = [
        {ModA, placement(x: 150, y: 150, unique_name: "Dup#x")},
        {ModB, placement(x: 150, y: 150, unique_name: "Dup#x")}
      ]

      assert {:error, errors} = Verifier.verify(entries)
      assert Enum.any?(errors, &match?({:cell_collision, {"prontera", 150, 150}, _mods}, &1))
    end
  end

  describe "verify!/1" do
    test "returns :ok for unique cells" do
      assert :ok = Verifier.verify!([{ModA, placement(x: 150, y: 150)}])
    end

    test "warns but does not raise at boot on a cell collision" do
      capture_log(fn ->
        assert :ok =
                 Verifier.verify!([
                   {ModA, placement(x: 150, y: 150)},
                   {ModB, placement(x: 150, y: 150)}
                 ])
      end)
    end
  end
end
