defmodule Aesir.ZoneServer.Mmo.Skill.SkillDbFlagsTest do
  @moduledoc """
  Pins every catalog skill's `damage_kind`, `damage_type`, `ignore_def_card`,
  `ignore_element` and `ignore_flee` to the skill DB's `Type`, `NoDamage`,
  `IgnoreDefCard`, `IgnoreElement` and `IgnoreFlee` columns in both modes, from
  the checked-in extract `test/support/fixtures/skill_db_types.tsv`. A mode
  without a row for the skill reads the other mode's row.
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
      [id, _name, re_type, re_nd, pre_type, pre_nd, re_ignore, pre_ignore] =
        String.split(line, "\t")

      re = row(re_type, re_nd, re_ignore)
      pre = row(pre_type, pre_nd, pre_ignore)
      {String.to_integer(id), %{renewal: re || pre, pre_renewal: pre || re}}
    end)
  end

  defp row("-", "-", "-"), do: nil

  defp row(type, no_damage, ignore) do
    ignore = String.split(ignore, ",")

    %{
      damage_kind: Map.fetch!(@kinds, type),
      damage_type: if(no_damage == "true", do: :no_damage, else: :damage),
      ignore_def_card: "IgnoreDefCard" in ignore,
      ignore_element: "IgnoreElement" in ignore,
      ignore_flee: "IgnoreFlee" in ignore
    }
  end

  defp declared(definition) do
    Map.take(definition, [
      :damage_kind,
      :damage_type,
      :ignore_def_card,
      :ignore_element,
      :ignore_flee
    ])
  end

  test "every catalog skill declares the skill DB type and damage flags in both modes" do
    rows = extract()

    mismatches =
      for %{name: name} <- Catalog.all(),
          {:ok, module} = Catalog.module_for(name),
          module != EnsembleSkill,
          mode <- [:renewal, :pre_renewal],
          definition = module.definition(mode),
          expected = rows |> Map.get(definition.id, %{}) |> Map.get(mode, :missing),
          expected != declared(definition) do
        {mode, definition.name, expected, declared(definition)}
      end

    assert mismatches == []
  end

  test "every misc damage skill a unit can use ignores flee in both modes" do
    dodgeable =
      for %{name: name} <- Catalog.all(),
          {:ok, module} = Catalog.module_for(name),
          module != EnsembleSkill,
          mode <- [:renewal, :pre_renewal],
          definition = module.definition(mode),
          definition.damage_kind == :misc,
          definition.damage_type == :damage,
          definition.target_type != :passive,
          not definition.ignore_flee do
        {mode, definition.name}
      end

    assert dodgeable == []
  end
end
