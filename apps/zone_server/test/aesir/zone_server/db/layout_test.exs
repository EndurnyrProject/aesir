defmodule Aesir.ZoneServer.Db.LayoutTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Db.Layout

  @domains [
    {"items", :glob, false, "aesir.import.items"},
    {"mobs", :glob, false, "aesir.import.mobs"},
    {"spawns", :glob, false, "aesir.import.spawns"},
    {"jobs", :glob, false, "aesir.import.jobs"},
    {"quests", :glob, false, "aesir.import.quests"},
    {"warps", :glob, false, "aesir.import.warps"},
    {"shops", :glob, false, "aesir.import.shops"},
    {"statpoint", :glob, false, "aesir.import.statpoint"},
    {"item_groups", :glob, false, "aesir.import.item_groups"},
    {"skill_tree", :glob, false, "aesir.import.skill_tree"},
    {"castles", :glob, false, "aesir.import.castles"},
    {"homunculus/species.yml", :file, false, "aesir.import.homunculi"},
    {"homunculus/exp.yml", :file, false, "aesir.import.homunculi"},
    {"homunculus/skill_trees.yml", :file, false, "aesir.import.homunculi"},
    {"produce/recipes.yml", :file, false, "aesir.import.produce"},
    {"produce/ore_discovery.yml", :file, false, "aesir.import.produce"},
    {"guild/exp.yml", :file, false, "aesir.import.guild"},
    {"guild/skill_tree.yml", :file, false, "aesir.import.guild"},
    {"refine/refine.yml", :file, false, "aesir.import.refine"},
    {"mob_skills/mob_skills.yml", :file, false, "aesir.import.mob_skills"},
    {"arrows.yml", :file, true, "aesir.import.arrows"},
    {"map_flags.yml", :file, true, nil},
    {"level_penalty.yml", :file, false, "aesir.import.level_penalty"},
    {"level_penalty_exp.yml", :file, false, "aesir.import.level_penalty"},
    {"level_penalty_mvp_drop.yml", :file, false, "aesir.import.level_penalty"},
    {"level_penalty_mvp_exp.yml", :file, false, "aesir.import.level_penalty"}
  ]

  test "maps database modes to their directories" do
    assert Layout.mode_dir(:renewal) == "re"
    assert Layout.mode_dir(:pre_renewal) == "pre-re"
  end

  test "classifies every database domain" do
    Enum.each(@domains, fn {domain, kind, shared?, import_task} ->
      assert Layout.kind(domain) == kind
      assert Layout.shared?(domain) == shared?
      assert Layout.import_task(domain) == import_task
    end)
  end

  test "resolves base and import paths for every database domain" do
    Enum.each(@domains, fn {domain, _kind, shared?, _import_task} ->
      renewal_path = if shared?, do: domain, else: Path.join("re", domain)
      pre_renewal_path = if shared?, do: domain, else: Path.join("pre-re", domain)

      assert Layout.rel_path(domain, :renewal) == renewal_path
      assert Layout.rel_path(domain, :pre_renewal) == pre_renewal_path
      assert Layout.import_rel_path(domain) == Path.join("import", domain)
    end)
  end
end
