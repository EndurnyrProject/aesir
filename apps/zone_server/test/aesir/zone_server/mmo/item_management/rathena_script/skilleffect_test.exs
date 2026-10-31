defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.SkilleffectTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.Importer
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Loader
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler

  setup context do
    Aesir.ZoneServer.DbTestSetup.configure_root(context, "items")
  end

  @tag :tmp_dir
  test "cached definitions from before the new restriction fields acquire their defaults", %{
    tmp_dir: dir
  } do
    source = Path.join(dir, "items.yml")
    File.write!(source, "[]\n")
    cache_dir = Path.join(dir, ".cache")
    File.mkdir_p!(cache_dir)
    old = %ItemDefinition{id: 501, aegis_name: "Potion", name: "Potion"}
    old = Map.drop(old, [:no_use_sitting, :use_override])

    File.write!(
      Path.join(cache_dir, "items_v9.etf"),
      :erlang.term_to_binary(%{sources: [source], term: [old]})
    )

    assert %{by_id: %{501 => loaded}} = Loader.load()
    assert loaded.no_use_sitting == false
    assert loaded.use_override == 100
  end

  test "skill visuals preserve conditional costs and subsequent status commands" do
    script = """
    if (Hp>15) {
      skilleffect "AL_INCAGI",0;
      sc_start SC_INCREASEAGI,240000,10;
      heal -15,0;
    }
    """

    assert {:ok, source} = Transpiler.transpile(script)
    assert source =~ "hp(ctx) > 15"
    assert source =~ "skilleffect(ctx, 29, 0)"
    assert source =~ "sc_start(ctx, :sc_increaseagi, 240000, 10)"
    assert source =~ "heal(ctx, hp: -15)"
    assert Code.string_to_quoted!(source)

    assert {:ok, wind} =
             Transpiler.transpile("skilleffect 383,0; sc_start SC_WINDWALK,250000,5;")

    assert wind =~ "sc_start(ctx, :sc_windwalk, 250000, 5)"
    assert {:error, {:unsupported, _}} = Transpiler.transpile("skilleffect 29,0,123;")
    assert {:error, {:unsupported, _}} = Transpiler.transpile("skilleffect \"NO_SUCH_SKILL\",0;")
  end

  test "sitting restrictions and their group override survive import and YAML serialization" do
    entry = %{
      "Id" => 12215,
      "AegisName" => "Blessing_10_Scroll",
      "Name" => "LV10 Blessing Scroll",
      "Type" => "Usable",
      "NoUse" => %{"Sitting" => true, "Override" => 80}
    }

    assert {:ok, definition} = Importer.to_definition(entry, :pre_renewal)
    yaml = Importer.to_yaml_map(definition, :pre_renewal)
    assert yaml["no_use_sitting"] == true
    assert yaml["use_override"] == 80

    assert {:ok, default} = Importer.to_definition(Map.delete(entry, "NoUse"), :pre_renewal)
    assert default.no_use_sitting == false
    assert default.use_override == 100
  end
end
