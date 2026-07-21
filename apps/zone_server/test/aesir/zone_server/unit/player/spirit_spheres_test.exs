defmodule Aesir.ZoneServer.Unit.Player.SpiritSpheresTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  test "summoning at the cap replaces the oldest sphere" do
    spheres = SpiritSpheres.new()
    {spheres, first} = SpiritSpheres.summon(spheres, 100, 2)
    {spheres, second} = SpiritSpheres.summon(spheres, 200, 2)
    {spheres, third} = SpiritSpheres.summon(spheres, 300, 2)

    assert SpiritSpheres.count(spheres) == 2
    assert SpiritSpheres.entries(spheres) == [second, third]
    refute Enum.any?(SpiritSpheres.entries(spheres), &(&1.id == first.id))
  end

  test "summoning at the cap replaces the oldest unreserved sphere" do
    {spheres, first} = SpiritSpheres.new() |> SpiritSpheres.summon(100, 2)
    {spheres, second} = SpiritSpheres.summon(spheres, 200, 2)
    assert {:ok, spheres, [reserved]} = SpiritSpheres.reserve(spheres, :transfer, 1)
    assert reserved.id == first.id

    {spheres, third} = SpiritSpheres.summon(spheres, 300, 2)

    assert Enum.map(SpiritSpheres.entries(spheres), & &1.id) == [first.id, third.id]
    refute Enum.any?(SpiritSpheres.entries(spheres), &(&1.id == second.id))
  end

  test "summoning at the cap rejects when every sphere is reserved" do
    {spheres, _} = SpiritSpheres.new() |> SpiritSpheres.summon(100, 2)
    {spheres, _} = SpiritSpheres.summon(spheres, 200, 2)
    assert {:ok, spheres, _reserved} = SpiritSpheres.reserve(spheres, :transfer, 2)

    assert SpiritSpheres.summon(spheres, 300, 2) == {:error, :all_reserved}
  end

  test "reserving and consuming select the oldest unreserved spheres" do
    {spheres, first} = SpiritSpheres.new() |> SpiritSpheres.summon(100, 5)
    {spheres, second} = SpiritSpheres.summon(spheres, 200, 5)
    {spheres, third} = SpiritSpheres.summon(spheres, 300, 5)

    assert {:ok, spheres, [^first, ^second]} = SpiritSpheres.reserve(spheres, :transfer, 2)
    assert {:ok, spheres, [^third]} = SpiritSpheres.consume(spheres, 1)
    expected_entry_ids = [first.id, second.id]

    assert {:ok, spheres, consumed} =
             SpiritSpheres.consume_reserved(spheres, :transfer, expected_entry_ids)

    assert Enum.map(consumed, & &1.id) == [first.id, second.id]
    assert SpiritSpheres.count(spheres) == 0
  end

  test "expires all due spheres in one transition and preserves later entries" do
    {spheres, first} = SpiritSpheres.new() |> SpiritSpheres.summon(100, 5)
    {spheres, second} = SpiritSpheres.summon(spheres, 100, 5)
    {spheres, third} = SpiritSpheres.summon(spheres, 101, 5)

    assert {spheres, [^first, ^second]} = SpiritSpheres.expire_due(spheres, 100)
    assert SpiritSpheres.entries(spheres) == [third]
    assert SpiritSpheres.next_expiry(spheres) == 101
  end

  test "reserved consumption rejects an incomplete original entry set" do
    {spheres, first} = SpiritSpheres.new() |> SpiritSpheres.summon(100, 5)
    {spheres, second} = SpiritSpheres.summon(spheres, 200, 5)
    assert {:ok, spheres, _} = SpiritSpheres.reserve(spheres, :transfer, 2)
    {spheres, [expired]} = SpiritSpheres.expire_due(spheres, 100)
    assert expired.id == first.id

    assert SpiritSpheres.consume_reserved(spheres, :transfer, [first.id, second.id]) ==
             {:error, :reservation_changed}
  end
end
