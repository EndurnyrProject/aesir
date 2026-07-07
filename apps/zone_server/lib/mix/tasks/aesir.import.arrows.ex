defmodule Mix.Tasks.Aesir.Import.Arrows do
  @shortdoc "Imports the rAthena arrow crafting table into priv/db/arrows.yml"
  @moduledoc """
  One-time importer: converts rAthena's `db/create_arrow_db.yml` (the
  AC_MAKINGARROW crafting table) into our own-schema YAML at
  `apps/zone_server/priv/db/arrows.yml`.

      mix aesir.import.arrows [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. AegisNames are resolved to numeric
  item ids against our item catalog (`ItemManagement.Items`); a recipe whose
  source item is unknown is dropped, and unknown produced items are dropped from
  their recipe (a recipe producing nothing is dropped too), so the data file
  never references items the server cannot give. The run reports how many
  recipes were written and how many entries were skipped. Run only when syncing
  rAthena.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  @out_file Path.join(~w(apps zone_server priv db arrows.yml))
  @source_db Path.join(~w(db create_arrow_db.yml))

  @impl Mix.Task
  def run(args) do
    rathena = List.first(args) || "../rathena"

    entries =
      rathena
      |> Path.join(@source_db)
      |> YamlElixir.read_from_file!()
      |> Map.fetch!("Body")

    {recipes, skipped} = convert(entries)

    File.write!(@out_file, Ymlr.document!(recipes))
    report(entries, recipes, skipped)
  end

  @spec convert([map()]) :: {[map()], [{String.t(), atom()}]}
  defp convert(entries) do
    Enum.reduce(entries, {[], []}, fn %{"Source" => source} = entry, {recipes, skipped} ->
      case build_recipe(source, Map.get(entry, "Make", [])) do
        {:ok, recipe, dropped} -> {[recipe | recipes], dropped ++ skipped}
        {:error, reason} -> {recipes, [{source, reason} | skipped]}
      end
    end)
    |> then(fn {recipes, skipped} ->
      {Enum.sort_by(Enum.reverse(recipes), & &1["source"]), Enum.reverse(skipped)}
    end)
  end

  @spec build_recipe(String.t(), [map()]) ::
          {:ok, map(), [{String.t(), atom()}]} | {:error, atom()}
  defp build_recipe(source, makes) do
    with {:ok, source_def} <- resolve(source),
         {resolved, dropped} <- resolve_makes(makes),
         {:ok, resolved} <- non_empty(resolved) do
      {:ok, %{"source" => source_def.id, "make" => resolved}, dropped}
    else
      :error -> {:error, :unknown_source_item}
      :empty -> {:error, :no_resolvable_products}
    end
  end

  @spec resolve_makes([map()]) :: {[map()], [{String.t(), atom()}]}
  defp resolve_makes(makes) do
    Enum.reduce(makes, {[], []}, fn %{"Item" => aegis, "Amount" => amount}, {ok, dropped} ->
      case resolve(aegis) do
        {:ok, item_def} -> {ok ++ [%{"item" => item_def.id, "amount" => amount}], dropped}
        :error -> {ok, dropped ++ [{aegis, :unknown_product_item}]}
      end
    end)
  end

  @spec non_empty([map()]) :: {:ok, [map()]} | :empty
  defp non_empty([]), do: :empty
  defp non_empty(resolved), do: {:ok, resolved}

  @spec resolve(String.t()) :: {:ok, ItemDefinition.t()} | :error
  defp resolve(aegis), do: Items.by_aegis(aegis)

  @spec report([map()], [map()], [{String.t(), atom()}]) :: :ok
  defp report(entries, recipes, skipped) do
    Mix.shell().info("arrows: parsed #{length(entries)} recipes")
    Mix.shell().info("  wrote #{length(recipes)} -> #{@out_file}")

    unless skipped == [] do
      freq = skipped |> Enum.map(fn {_aegis, reason} -> reason end) |> Enum.frequencies()
      Mix.shell().info("  skipped #{length(skipped)} entries: #{inspect(freq)}")
    end

    :ok
  end
end
