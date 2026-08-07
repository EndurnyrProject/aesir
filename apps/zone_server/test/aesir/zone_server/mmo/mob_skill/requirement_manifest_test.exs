defmodule Aesir.ZoneServer.Mmo.MobSkill.RequirementManifestTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobSkill.Importer
  alias Aesir.ZoneServer.Mmo.Skill.Catalog

  @assassin_skill_ids 132..141
  @compatible_assassin_counts %{135 => 93, 136 => 121, 137 => 58, 140 => 58, 141 => 1}

  test "every resolving mob-row skill explicitly declares its requirements" do
    rows =
      :zone_server
      |> Application.app_dir("priv/db/mob_skills/mob_skills.yml")
      |> YamlElixir.read_from_file!()
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq_by(& &1["skill_id"])

    missing_declarations =
      for row <- rows,
          {:ok, definition} <- [Catalog.by_id(row["skill_id"])],
          {:ok, module} <- [Catalog.active_module_for(definition.name)],
          not explicitly_declares_requirements?(module),
          do: "#{row["skill"]} (#{definition.name}, #{definition.id})"

    assert missing_declarations == [], """
    mob-row skills resolved without an explicit requires: declaration:
    #{Enum.join(missing_declarations, "\n")}
    """

    split = Enum.frequencies_by(rows, &Importer.classify(&1["skill_id"]))
    castable = Map.get(split, :castable, 0)
    unresolved = Map.get(split, :unresolved, 0)

    uncastable =
      Enum.reduce(split, 0, fn
        {{:uncastable, {:missing, _requirements}}, count}, total -> total + count
        {_classification, _count}, total -> total
      end)

    assert castable + uncastable + unresolved == length(rows)

    IO.puts(
      "mob skill requirement manifest: #{length(rows)} ids; " <>
        "#{castable} castable, #{uncastable} uncastable-with-reason, #{unresolved} unresolved"
    )
  end

  test "every imported Assassin row is explicitly mob-compatible" do
    rows =
      :zone_server
      |> Application.app_dir("priv/db/mob_skills/mob_skills.yml")
      |> YamlElixir.read_from_file!()
      |> Enum.flat_map(fn {mob_id, rows} ->
        Enum.map(rows, &{mob_id, &1})
      end)
      |> Enum.filter(fn {_mob_id, row} -> row["skill_id"] in @assassin_skill_ids end)

    assert Enum.frequencies_by(rows, fn {_mob_id, row} -> row["skill_id"] end) ==
             @compatible_assassin_counts

    incompatible =
      for {mob_id, row} <- rows,
          classification = Importer.classify(row["skill_id"]),
          classification != :castable,
          do: "mob #{mob_id}: #{row["skill"]} (#{row["skill_id"]}) => #{inspect(classification)}"

    assert incompatible == [], """
    imported Assassin rows were not mob-castable:
    #{Enum.join(incompatible, "\n")}
    """

    Enum.each(rows, fn {_mob_id, row} ->
      assert {:ok, definition} = Catalog.by_id(row["skill_id"])
      assert definition.requires == []
      assert {:ok, module} = Catalog.active_module_for(definition.name)
      assert explicitly_declares_requirements?(module)
    end)
  end

  # Uses the compile-time flag the `use Skill` macro records, rather than runtime
  # source inspection (which races with Mimic's module recompilation).
  defp explicitly_declares_requirements?(module) do
    function_exported?(module, :__requires_declared__, 0) and module.__requires_declared__()
  end
end
