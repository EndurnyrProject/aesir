defmodule Aesir.ZoneServer.Mmo.Homunculus.Catalogs do
  @moduledoc """
  Loads Homunculus catalogs in dependency order and validates their shared keys.
  """

  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog
  alias Aesir.ZoneServer.Mmo.Homunculus.ExpTable
  alias Aesir.ZoneServer.Mmo.Homunculus.SkillTree

  @pt_key __MODULE__

  @doc "Reloads every Homunculus catalog and rejects cross-catalog inconsistencies."
  @spec reload() :: :ok
  def reload do
    install_staged(Catalog.stage(), ExpTable.stage(), SkillTree.stage())
  end

  @doc false
  @spec reload(Path.t(), Path.t(), Path.t()) :: :ok
  def reload(species_path, exp_path, skill_tree_path) do
    install_staged(
      Catalog.stage(species_path),
      ExpTable.stage(exp_path),
      SkillTree.stage(skill_tree_path)
    )
  end

  @doc "Returns the generation shared by all three public catalogs."
  @spec generation() :: non_neg_integer()
  def generation, do: snapshot().generation

  @doc false
  @spec state(:catalog | :exp_table | :skill_tree) :: map()
  def state(component), do: Map.fetch!(snapshot(), component)

  @doc "Validates the currently loaded species and skill-tree catalogs."
  @spec validate!() :: :ok
  def validate!, do: validate!(Catalog.all(), SkillTree.all())

  @doc false
  @spec validate!([map()], [map()]) :: :ok
  def validate!(species, trees) do
    species_by_class = Map.new(species, &{field(&1, :id), MapSet.new(field(&1, :skills))})

    trees_by_class =
      trees
      |> Enum.group_by(&field(&1, :class_id))
      |> Map.new(fn {id, rows} -> {id, MapSet.new(rows, &field(&1, :skill_id))} end)

    require!(
      MapSet.new(Map.keys(species_by_class)) == MapSet.new(Map.keys(trees_by_class)),
      "catalog class mismatch"
    )

    Enum.each(species_by_class, fn {class_id, skill_ids} ->
      require!(
        skill_ids == Map.fetch!(trees_by_class, class_id),
        "catalog skill mismatch for class #{class_id}"
      )
    end)

    :ok
  end

  defp install_staged(catalog, exp_table, skill_tree) do
    validate!(catalog.all, skill_tree.all)

    generation =
      case :persistent_term.get(@pt_key, nil) do
        nil -> 1
        snapshot -> snapshot.generation + 1
      end

    :persistent_term.put(@pt_key, %{
      generation: generation,
      catalog: catalog,
      exp_table: exp_table,
      skill_tree: skill_tree
    })

    :ok
  end

  defp snapshot do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        reload()
        :persistent_term.get(@pt_key)

      snapshot ->
        snapshot
    end
  end

  defp field(row, key), do: Map.get(row, key, Map.get(row, Atom.to_string(key)))
  defp require!(true, _message), do: :ok
  defp require!(false, message), do: raise(ArgumentError, message)
end
