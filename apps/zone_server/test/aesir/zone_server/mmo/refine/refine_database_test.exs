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
    # This test deliberately reloads with a stubbed-out Items lookup, which writes the
    # corrupted (nil-material) table into the shared :persistent_term. Restore the real
    # table on exit (the stub is gone by then) so the corruption can't leak to other modules.
    on_exit(fn -> RefineDatabase.reload() end)

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

  describe "import overlay" do
    setup context do
      on_exit(&RefineDatabase.reload/0)
      Aesir.ZoneServer.DbTestSetup.configure_root(context, "refine")
    end

    @tag :tmp_dir
    test "reload replaces an imported refine group without changing other groups", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "refine.yml"), """
      - group: armor
        levels:
          - level: 1
            refine_levels:
              - level: 1
                bonus: 100
                random_bonus: 0
                blacksmith_blessing_amount: 0
                broadcast_success: false
                broadcast_failure: false
                chances: []
      - group: weapon
        levels:
          - level: 1
            refine_levels:
              - level: 1
                bonus: 200
                random_bonus: 0
                blacksmith_blessing_amount: 0
                broadcast_success: false
                broadcast_failure: false
                chances: []
      """)

      import = Path.join([dir, "..", "..", "import", "refine", "refine.yml"])
      File.mkdir_p!(Path.dirname(import))

      File.write!(import, """
      - group: armor
        levels:
          - level: 1
            refine_levels:
              - level: 1
                bonus: 999
                random_bonus: 0
                blacksmith_blessing_amount: 0
                broadcast_success: false
                broadcast_failure: false
                chances: []
      """)

      assert :ok = RefineDatabase.reload()
      assert %{bonus: 999} = RefineDatabase.level_info(:armor, 1, 1)
      assert %{bonus: 200} = RefineDatabase.level_info(:weapon, 1, 1)
    end
  end
end
