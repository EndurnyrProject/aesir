defmodule Aesir.ZoneServer.Mmo.Refine.RefineDatabaseTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.ZoneServer.Factory
  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.DbTestSetup
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.Refine.Chance
  alias Aesir.ZoneServer.Mmo.Refine.LevelInfo
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase

  @moduletag :tmp_dir

  @table """
  - group: weapon
    levels:
      - level: 2
        refine_levels:
          - level: 3
            bonus: 200
            random_bonus: 80
            blacksmith_blessing_amount: 2
            broadcast_success: true
            broadcast_failure: true
            chances: &ore_options
              - type: normal
                rate: 7531
                price: 4200
                material: Test_Ore
                breaking_rate: 1500
                downgrade_amount: 2
      - level: 3
        refine_levels:
          - level: 3
            bonus: 300
            random_bonus: 0
            blacksmith_blessing_amount: 0
            broadcast_success: false
            broadcast_failure: false
            chances: *ore_options
  - group: armor
    levels:
      - level: 2
        refine_levels:
          - level: 3
            bonus: 500
            random_bonus: 0
            blacksmith_blessing_amount: 0
            broadcast_success: false
            broadcast_failure: false
            chances: []
  """

  setup :set_mimic_from_context

  setup context do
    on_exit(&RefineDatabase.reload/0)
    {:ok, tmp_dir: base} = DbTestSetup.configure_root(context, "refine")
    File.write!(Path.join(base, "refine.yml"), @table)
    ore = build(:item_definition, id: 1010, aegis_name: "Test_Ore")
    stub(Items, :by_aegis, fn "Test_Ore" -> {:ok, ore} end)
    :ok
  end

  test "indexes literal levels and resolves the ore name to its item id" do
    assert :ok = RefineDatabase.reload()

    assert %LevelInfo{
             bonus: 200,
             randombonus_max: 80,
             blessing_amount: 2,
             broadcast_success: true,
             broadcast_failure: true,
             chances: %{
               normal: %Chance{
                 rate: 7531,
                 price: 4200,
                 material_nameid: 1010,
                 breaking_rate: 1500,
                 downgrade: 2
               }
             }
           } = RefineDatabase.level_info(:weapon, 2, 3)

    assert %LevelInfo{bonus: 300} = RefineDatabase.level_info(:weapon, 3, 3)
    assert %LevelInfo{bonus: 500} = RefineDatabase.level_info(:armor, 2, 3)
    assert RefineDatabase.level_info(:weapon, 2, 2) == nil
  end

  test "leaves unresolved ore ids unset and warns about the missing reference" do
    stub(Items, :by_aegis, fn "Test_Ore" -> :error end)

    log = capture_log(fn -> assert :ok = RefineDatabase.reload() end)
    assert [_warning] = Regex.scan(~r/unresolved material aegis "Test_Ore"/, log)

    assert %LevelInfo{chances: %{normal: %Chance{material_nameid: nil}}} =
             RefineDatabase.level_info(:weapon, 2, 3)
  end

  test "reload replaces an imported refine group without changing other groups", %{tmp_dir: root} do
    assert :ok = RefineDatabase.reload()

    import = Path.join([root, "import", "refine", "refine.yml"])
    File.mkdir_p!(Path.dirname(import))

    File.write!(import, """
    - group: armor
      levels:
        - level: 2
          refine_levels:
            - level: 3
              bonus: 999
              random_bonus: 0
              blacksmith_blessing_amount: 0
              broadcast_success: false
              broadcast_failure: false
              chances: []
    """)

    assert :ok = RefineDatabase.reload()
    assert %LevelInfo{bonus: 999} = RefineDatabase.level_info(:armor, 2, 3)
    assert %LevelInfo{bonus: 200} = RefineDatabase.level_info(:weapon, 2, 3)
  end
end
