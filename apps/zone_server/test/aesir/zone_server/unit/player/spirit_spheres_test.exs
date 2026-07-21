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

  test "adding a received sphere keeps existing spheres and rejects at the cap" do
    {spheres, first} = SpiritSpheres.new() |> SpiritSpheres.summon(100, 2)

    assert {:ok, spheres, second} = SpiritSpheres.add_if_below_cap(spheres, 200, 2)
    assert SpiritSpheres.entries(spheres) == [first, second]
    assert SpiritSpheres.add_if_below_cap(spheres, 300, 2) == {:error, :full}
  end

  test "consuming removes the oldest spheres" do
    {spheres, first} = SpiritSpheres.new() |> SpiritSpheres.summon(100, 5)
    {spheres, second} = SpiritSpheres.summon(spheres, 200, 5)
    {spheres, third} = SpiritSpheres.summon(spheres, 300, 5)

    assert {:ok, spheres, [^first, ^second]} = SpiritSpheres.consume(spheres, 2)
    assert SpiritSpheres.entries(spheres) == [third]
  end

  test "expires all due spheres in one transition and preserves later entries" do
    {spheres, first} = SpiritSpheres.new() |> SpiritSpheres.summon(100, 5)
    {spheres, second} = SpiritSpheres.summon(spheres, 100, 5)
    {spheres, third} = SpiritSpheres.summon(spheres, 101, 5)

    assert {spheres, [^first, ^second]} = SpiritSpheres.expire_due(spheres, 100)
    assert SpiritSpheres.entries(spheres) == [third]
    assert SpiritSpheres.next_expiry(spheres) == 101
  end
end
