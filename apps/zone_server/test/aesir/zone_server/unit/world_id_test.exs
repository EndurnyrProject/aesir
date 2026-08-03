defmodule Aesir.ZoneServer.Unit.WorldIdTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.WorldId

  @unit_types [:player, :mob, :npc, :pet, :homunculus, :mercenary, :skill_unit]

  setup :setup_ets_tables

  test "allocates both bounds inclusively" do
    UnitRegistry.register_unit(:player, 3, __MODULE__, %{})
    assert {:ok, 2} = WorldId.allocate(2..3)

    UnitRegistry.unregister_unit(:player, 3)
    UnitRegistry.register_unit(:player, 2, __MODULE__, %{})
    assert {:ok, 3} = WorldId.allocate(2..3)
  end

  test "allocates a free singleton and reports an occupied singleton exhausted" do
    assert {:ok, 2} = WorldId.allocate(2..2)

    UnitRegistry.register_unit(:npc, 2, __MODULE__, %{})
    assert {:error, :exhausted} = WorldId.allocate(2..2)
  end

  test "falls back from repeated randomized collisions without looping" do
    for id <- 2..4, do: UnitRegistry.register_unit(:player, id, __MODULE__, %{})

    :rand.seed(:exsss, {1, 2, 3})

    for _ <- 1..3 do
      assert {:ok, 5} = WorldId.allocate(2..5)
    end
  end

  test "reports exhaustion after checking every candidate" do
    for id <- 2..4, do: UnitRegistry.register_unit(:player, id, __MODULE__, %{})

    assert {:error, :exhausted} = WorldId.allocate(2..4)
  end

  test "skips IDs registered by every accepted unit type" do
    @unit_types
    |> Enum.with_index(2)
    |> Enum.each(fn {unit_type, id} ->
      UnitRegistry.register_unit(unit_type, id, __MODULE__, %{})
    end)

    assert {:ok, 9} = WorldId.allocate(2..9)
  end

  test "reuses an ID after registry cleanup" do
    UnitRegistry.register_unit(:npc, 2, __MODULE__, %{})
    UnitRegistry.register_unit(:homunculus, 3, __MODULE__, %{}, self())

    assert :ok = UnitRegistry.cleanup_units_for_pid(self())
    refute UnitRegistry.unit_id_exists?(3)
    assert {:ok, 3} = WorldId.allocate(2..3)
  end
end
