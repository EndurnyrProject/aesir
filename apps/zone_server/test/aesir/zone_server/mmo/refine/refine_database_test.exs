defmodule Aesir.ZoneServer.Mmo.Refine.RefineDatabaseTest do
  use ExUnit.Case, async: false
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase

  setup :verify_on_exit!

  setup do
    :ok = RefineDatabase.reload()
  end

  test "level_info/3 resolves a weapon yml level 1 entry with a resolved material nameid" do
    info = RefineDatabase.level_info(:weapon, 1, 1)

    assert %{bonus: 200, chances: %{normal: %{rate: 10000}}} = info
    assert is_integer(info.chances.normal.material_nameid)
  end

  test "level_info/3 exposes the first risky armor step (+4 -> +5)" do
    assert %{chances: %{normal: %{breaking_rate: 10000}}} =
             RefineDatabase.level_info(:armor, 1, 5)

    assert %{chances: %{normal: %{rate: 10000, breaking_rate: 0}}} =
             RefineDatabase.level_info(:armor, 1, 4)
  end

  test "level_info/3 returns nil for an absent triple" do
    assert RefineDatabase.level_info(:weapon, 1, 21) == nil
    assert RefineDatabase.level_info(:weapon, 999, 1) == nil
  end

  test "reload/0 leaves material_nameid nil and logs a single warning for an unresolved aegis" do
    stub(Items, :by_aegis, fn
      "Phracon" -> :error
      aegis -> call_original(Items, :by_aegis, [aegis])
    end)

    log =
      capture_log(fn ->
        assert :ok = RefineDatabase.reload()
      end)

    assert RefineDatabase.level_info(:weapon, 1, 1).chances.normal.material_nameid == nil
    assert [_] = Regex.scan(~r/unresolved material aegis "Phracon"/, log)
  end

  test "reload/0 is idempotent" do
    :ok = RefineDatabase.reload()
    :ok = RefineDatabase.reload()

    assert RefineDatabase.level_info(:weapon, 1, 1).bonus == 200
  end
end
