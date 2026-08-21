defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes do
  @moduledoc """
  Runtime catalog of production recipes.
  """

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Mmo.DataLoader

  @pt_key __MODULE__

  defmodule Recipe do
    @moduledoc """
    A production recipe and its material requirements.
    """

    @enforce_keys [:id, :product_id, :item_level, :skill_id, :skill_level, :materials]
    defstruct [:id, :product_id, :item_level, :skill_id, :skill_level, :materials]

    @typedoc "A material requirement, including possession-only requirements with an amount of zero."
    @type material() :: %{item_id: integer(), amount: non_neg_integer()}

    @typedoc "A production recipe."
    @type t() :: %__MODULE__{
            id: integer(),
            product_id: integer(),
            item_level: integer(),
            skill_id: integer(),
            skill_level: integer(),
            materials: [material()]
          }
  end

  @doc "Returns every production recipe."
  @spec all() :: [Recipe.t()]
  def all, do: index().all

  @doc "Returns the recipe with `id`, or `:error` when it does not exist."
  @spec by_id(integer()) :: {:ok, Recipe.t()} | :error
  def by_id(id), do: Map.fetch(index().by_id, id)

  @doc "Returns recipes a cast at `skill_level` may offer for `skill_id`."
  @spec offerable(integer(), integer()) :: [Recipe.t()]
  def offerable(skill_id, skill_level) do
    Enum.filter(index().all, fn recipe ->
      recipe.skill_id == skill_id and recipe.skill_level <= skill_level and
        (not weapon_recipe?(recipe) or recipe.item_level <= skill_level)
    end)
  end

  @doc "Rebuilds the cached recipe index from disk."
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, build())
    :ok
  end

  defp index do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = build()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  defp build do
    recipes =
      "produce/recipes.yml"
      |> Source.sources()
      |> Enum.flat_map(&YamlElixir.read_from_file!/1)
      |> Enum.map(&to_recipe/1)
      |> DataLoader.merge_by_key(& &1.id)

    %{all: recipes, by_id: Map.new(recipes, &{&1.id, &1})}
  end

  defp to_recipe(%{
         "id" => id,
         "product_id" => product_id,
         "item_level" => item_level,
         "skill_id" => skill_id,
         "skill_level" => skill_level,
         "materials" => materials
       }) do
    %Recipe{
      id: id,
      product_id: product_id,
      item_level: item_level,
      skill_id: skill_id,
      skill_level: skill_level,
      materials:
        Enum.map(materials, fn %{"item_id" => item_id, "amount" => amount} ->
          %{item_id: item_id, amount: amount}
        end)
    }
  end

  defp weapon_recipe?(%Recipe{skill_id: skill_id}), do: skill_id in 98..104
end
