defmodule Aesir.ZoneServer.Mmo.Skill.SkillDbFlagsTest do
  @moduledoc """
  Pins every catalog skill's `damage_kind` and `damage_type` to the skill DB's
  `Type` and `NoDamage` columns in both modes, from the checked-in extract
  `test/support/fixtures/skill_db_types.tsv`. A mode without a row for the skill
  reads the other mode's row.
  """
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.TestSupport.EnsembleSkill

  @extract Path.expand("../../../../support/fixtures/skill_db_types.tsv", __DIR__)
  @external_resource @extract

  @kinds %{"Weapon" => :weapon, "Magic" => :magic, "Misc" => :misc, "None" => :none}

  defp extract do
    @extract
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Map.new(fn line ->
      [id, _name, re_type, re_nd, pre_type, pre_nd] = String.split(line, "\t")
      re = row(re_type, re_nd)
      pre = row(pre_type, pre_nd)
      {String.to_integer(id), %{renewal: re || pre, pre_renewal: pre || re}}
    end)
  end

  defp row("-", "-"), do: nil

  defp row(type, no_damage),
    do: {Map.fetch!(@kinds, type), if(no_damage == "true", do: :no_damage, else: :damage)}

  test "every catalog skill declares the skill DB type and no-damage flag in both modes" do
    rows = extract()

    mismatches =
      for %{name: name} <- Catalog.all(),
          {:ok, module} = Catalog.module_for(name),
          module != EnsembleSkill,
          mode <- [:renewal, :pre_renewal],
          definition = module.definition(mode),
          expected = rows |> Map.get(definition.id, %{}) |> Map.get(mode, :missing),
          expected != {definition.damage_kind, definition.damage_type} do
        {mode, definition.name, expected, {definition.damage_kind, definition.damage_type}}
      end

    assert mismatches == []
  end
end
