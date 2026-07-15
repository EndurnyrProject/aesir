defmodule Aesir.ZoneServer.Mmo.Skill.Unit.IdTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Id
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "classifies only the documented skill-unit uint32 range" do
    assert Id.skill_unit?(Id.first())
    assert Id.skill_unit?(Id.last())
    refute Id.skill_unit?(Id.first() - 1)
    refute Id.skill_unit?(Id.last() + 1)
  end

  test "skips ids occupied by cell storage or any registered unit" do
    assert {:ok, id} = Id.allocate(start: Id.first())
    :ets.insert(Aesir.ZoneServer.EtsTable.table_for(:skill_unit_cells), {id, :occupied})
    UnitRegistry.register_unit(:player, id + 1, __MODULE__, %{})

    assert {:ok, allocated} = Id.allocate(start: id)
    assert allocated == id + 2
  end

  test "reuses an id after process cleanup removes its registry index" do
    id = Id.first()
    UnitRegistry.register_unit(:player, id, __MODULE__, %{}, self())
    assert UnitRegistry.unit_id_exists?(id)

    assert :ok = UnitRegistry.cleanup_units_for_pid(self())
    refute UnitRegistry.unit_id_exists?(id)
    assert {:ok, ^id} = Id.allocate(start: id)
  end
end
