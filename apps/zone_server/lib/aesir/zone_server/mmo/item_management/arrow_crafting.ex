defmodule Aesir.ZoneServer.Mmo.ItemManagement.ArrowCrafting do
  @moduledoc """
  Registry of Arrow Crafting recipes, loaded as data from `priv/db/arrows.yml`
  (written by `mix aesir.import.arrows`). The recipes are era-independent: one
  shared table serves both renewal and pre-renewal.

  Each recipe converts 1 source item into a fixed set of produced items; a
  craft consumes exactly one source. The index is cached in `:persistent_term`;
  `reload/0` rebuilds it after the data file changes in a long-running session.
  Same API shape as `Items` / `Mobs`.
  """

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Mmo.DataLoader

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
      "arrows.yml"
      |> Source.sources()
      |> Enum.flat_map(&YamlElixir.read_from_file!/1)
      |> Enum.map(&to_recipe/1)
      |> DataLoader.merge_by_key(& &1.source_id)

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
