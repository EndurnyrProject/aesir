defmodule Aesir.ZoneServer.Mmo.ItemManagement.ArrowCrafting do
  @moduledoc """
  Registry of AC_MAKINGARROW crafting recipes, loaded as data from
  `priv/db/arrows.yml` (imported from rAthena's `create_arrow_db.yml` by
  `mix aesir.import.arrows`).

  Each recipe converts 1 source item into a fixed set of produced items
  (`skill_arrow_create` consumes exactly one source per craft). The index is
  cached in `:persistent_term`; `reload/0` rebuilds it after the data file
  changes in a long-running session. Same API shape as `Items` / `Mobs`.
  """

  @pt_key __MODULE__

  defmodule Recipe do
    @moduledoc false

    @enforce_keys [:source_id, :makes]
    defstruct [:source_id, :makes]

    @typedoc "One crafting recipe: 1 source item -> the produced item stacks."
    @type t() :: %__MODULE__{
            source_id: integer(),
            makes: [%{item_id: integer(), amount: pos_integer()}]
          }
  end

  @doc "Every recipe, in source-id order."
  @spec all() :: [Recipe.t()]
  def all, do: index().all

  @doc "The recipe consuming `source_id`, or `:error` when it crafts nothing."
  @spec for_source(integer()) :: {:ok, Recipe.t()} | :error
  def for_source(source_id), do: Map.fetch(index().by_source, source_id)

  @doc "Rebuilds the cached index after the data file changes."
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
      :zone_server
      |> Application.app_dir("priv/db/arrows.yml")
      |> YamlElixir.read_from_file!()
      |> Enum.map(&to_recipe/1)

    %{all: recipes, by_source: Map.new(recipes, &{&1.source_id, &1})}
  end

  defp to_recipe(%{"source" => source_id, "make" => makes}) do
    %Recipe{
      source_id: source_id,
      makes:
        Enum.map(makes, fn %{"item" => id, "amount" => amount} ->
          %{item_id: id, amount: amount}
        end)
    }
  end
end
