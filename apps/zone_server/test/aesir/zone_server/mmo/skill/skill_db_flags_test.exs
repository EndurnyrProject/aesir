defmodule Aesir.ZoneServer.Mmo.Skill.SkillDbFlagsTest do
  @moduledoc """
  Pins every catalog skill's `damage_kind`, `damage_type`, `ignore_def_card`,
  `ignore_element`, `ignore_flee`, `require_ammo` and `ammo_qty` to the skill
  DB's `Type`, `NoDamage`, `IgnoreDefCard`, `IgnoreElement`, `IgnoreFlee`,
  `Requires: Ammo` and `AmmoAmount` columns in both modes, from the checked-in
  extract `test/support/fixtures/skill_db_types.tsv`. A mode without a row for
  the skill reads the other mode's row.
  """
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.TestSupport.EnsembleSkill

  @extract Path.expand("../../../../support/fixtures/skill_db_types.tsv", __DIR__)
  @external_resource @extract

  @kinds %{"Weapon" => :weapon, "Magic" => :magic, "Misc" => :misc, "None" => :none}

  @ammo %{
    "Arrow" => :arrow,
    "Bullet" => :bullet,
    "Cannonball" => :cannonball,
    "Dagger" => :dagger,
    "Grenade" => :grenade,
    "Kunai" => :kunai,
    "Shell" => :shell,
    "Shuriken" => :shuriken,
    "Throwweapon" => :throw_weapon
  }

  defp extract do
    @extract
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Map.new(fn line ->
      [
        id,
        _name,
        re_type,
        re_nd,
        pre_type,
        pre_nd,
        re_ignore,
        pre_ignore,
        re_ammo,
        re_amounts,
        pre_ammo,
        pre_amounts
      ] = String.split(line, "\t")

      re = row(re_type, re_nd, re_ignore, re_ammo, re_amounts)
      pre = row(pre_type, pre_nd, pre_ignore, pre_ammo, pre_amounts)
      {String.to_integer(id), %{renewal: re || pre, pre_renewal: pre || re}}
    end)
  end

  defp row("-", "-", "-", "-", "-"), do: nil

  defp row(type, no_damage, ignore, ammo, amounts) do
    ignore = String.split(ignore, ",")

    %{
      damage_kind: Map.fetch!(@kinds, type),
      damage_type: if(no_damage == "true", do: :no_damage, else: :damage),
      ignore_def_card: "IgnoreDefCard" in ignore,
      ignore_element: "IgnoreElement" in ignore,
      ignore_flee: "IgnoreFlee" in ignore,
      require_ammo: ammo_types(ammo),
      ammo_qty: amounts |> String.split(",") |> Enum.map(&String.to_integer/1)
    }
  end

  defp ammo_types("none"), do: []

  defp ammo_types(names) do
    names
    |> String.split(",")
    |> Enum.map(&Map.fetch!(@ammo, &1))
    |> Enum.sort()
  end

  defp declared(definition, expected) do
    definition
    |> Map.take([:damage_kind, :damage_type, :ignore_def_card, :ignore_element, :ignore_flee])
    |> Map.merge(%{
      require_ammo: Enum.sort(definition.require_ammo),
      ammo_qty: ammo_sequence(definition, expected)
    })
  end

  # The extract's amounts run to the source row's own MaxLevel, which for a
  # shared NPC skill can differ from Aesir's declared level horizon, so only the
  # levels the source declares are compared.
  defp ammo_sequence(definition, %{ammo_qty: amounts}) do
    amounts
    |> Enum.with_index(1)
    |> Enum.map(fn {_amount, level} -> Definition.ammo_qty_at_level(definition, level) end)
  end

  defp ammo_sequence(_definition, _missing), do: []

  test "every catalog skill declares the skill DB type and damage flags in both modes" do
    rows = extract()

    mismatches =
      for %{name: name} <- Catalog.all(),
          {:ok, module} = Catalog.module_for(name),
          module != EnsembleSkill,
          mode <- [:renewal, :pre_renewal],
          definition = module.definition(mode),
          expected = rows |> Map.get(definition.id, %{}) |> Map.get(mode, :missing),
          expected != declared(definition, expected) do
        {mode, definition.name, expected, declared(definition, expected)}
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
