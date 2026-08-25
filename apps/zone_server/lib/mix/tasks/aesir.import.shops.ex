defmodule Mix.Tasks.Aesir.Import.Shops do
  @shortdoc "Imports enabled rAthena merchant shops into mode-scoped YAML"
  @moduledoc """
  Converts enabled merchant `npc:` rows from shared `npc/scripts_athena.conf`
  and selected `npc/{re,pre-re}/scripts_athena.conf` into
  `apps/zone_server/priv/db/<mode>/shops/*.yml`.

      mix aesir.import.shops [<rathena_root>] [--mode re|pre-re]

  `<rathena_root>` defaults to `../rathena`. Config declaration order is
  preserved; disabled merchant files are ignored.

  `duplicate(<label>)` shops carry no items of their own; they are resolved in a
  second pass from the placed shop whose `id` (full NPC name, including any
  `#suffix`) equals the label. A duplicate whose source is not a placed plain
  shop is dropped, with the reason naming the source kind so the count is not
  opaque: `:duplicate_of_script` (a dialog/`callshop`-driven `script` NPC),
  `:duplicate_of_cashshop` (a cash-point `cashshop` NPC), or
  `:unknown_duplicate_source` (no matching source found at all). The first two
  dominate merchant data and are out of scope for a data-only zeny-shop
  importer.

  Every resolved shop is sanitized so the data files stay boot-clean for the
  fatal `Aesir.ZoneServer.Npc.ShopVerifier`: a shop on an unknown map
  (`:unknown_map`) or a non-walkable cell (`:blocked_cell`) is dropped, and any
  buy-list item that does not resolve in the item DB is removed; a shop left
  with no valid items is dropped (`:no_valid_items`). The map cache is warmed the
  way the boot path does (`MapCache.init/0`); the item DB warms itself lazily on
  first lookup via `:persistent_term`, so no explicit boot is needed.

  The default-merchant-sprite count is not reported: the parser already applies
  the fallback for string-constant sprites, so a defaulted sprite is
  indistinguishable from a real `83` at this layer. The run prints how many shops
  were written, skipped by reason, and how many phantom items were dropped. Run
  only when syncing upstream data.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  alias Aesir.ZoneServer.Db.Layout
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Npc.Shops.Importer

  @shared_conf Path.join(~w(npc scripts_athena.conf))
  @mode_conf "scripts_athena.conf"

  @type shop_map :: Importer.shop_map()
  @type duplicate :: {String.t(), shop_map()}
  @type source :: {String.t(), Importer.source_type()}

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    out_dir = Import.path("shops", mode)
    boot_map_cache!()

    files = shop_files(rathena, mode)
    {shops, duplicates, sources, errors} = parse_files(files)
    Enum.each(errors, fn {file, line, reason} -> report_error(file, line, reason) end)

    {resolved, unresolved_reasons} = resolve_duplicates(shops, duplicates, Map.new(sources))
    {kept, skipped, dropped_items} = sanitize(resolved)
    skipped = unresolved_reasons ++ skipped

    write!(kept, out_dir)
    report(files, shops, duplicates, kept, skipped, dropped_items, errors, out_dir)
  end

  @spec boot_map_cache!() :: :ok
  defp boot_map_cache! do
    :ets.new(:map_cache, [:set, :public, :named_table, read_concurrency: true])
    MapCache.init()
  end

  @spec shop_files(Path.t(), Layout.mode()) :: [Path.t()]
  defp shop_files(rathena, mode) do
    mode_conf = Path.join(["npc", Layout.mode_dir(mode), @mode_conf])

    [@shared_conf, mode_conf]
    |> Enum.flat_map(fn conf ->
      conf |> then(&Path.join(rathena, &1)) |> merchant_files(rathena)
    end)
  end

  defp merchant_files(conf, rathena) do
    conf
    |> File.read!()
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case Regex.run(~r/^\s*npc:\s*(npc\/(?:re\/|pre-re\/)?merchants\/\S+\.txt)\s*$/, line) do
        [_, path] -> [Path.join(rathena, path)]
        nil -> []
      end
    end)
  end

  @spec parse_files([Path.t()]) ::
          {[shop_map()], [duplicate()], [source()], [{Path.t(), pos_integer(), term()}]}
  defp parse_files(files) do
    Enum.reduce(files, {[], [], [], []}, fn file, {shops, duplicates, sources, errors} ->
      {file_shops, file_duplicates, file_sources, file_errors} = parse_file(file)

      {shops ++ file_shops, duplicates ++ file_duplicates, sources ++ file_sources,
       errors ++ file_errors}
    end)
  end

  @spec parse_file(Path.t()) ::
          {[shop_map()], [duplicate()], [source()], [{Path.t(), pos_integer(), term()}]}
  defp parse_file(file) do
    file
    |> File.read!()
    |> then(&:binary.split(&1, "\n", [:global]))
    |> Enum.with_index(1)
    |> Enum.reduce({[], [], [], []}, fn {line, number}, {shops, duplicates, sources, errors} ->
      case Importer.parse_line(line) do
        {:ok, shop} -> {[shop | shops], duplicates, sources, errors}
        {:duplicate, label, partial} -> {shops, [{label, partial} | duplicates], sources, errors}
        {:source, type, exname} -> {shops, duplicates, [{exname, type} | sources], errors}
        :skip -> {shops, duplicates, sources, errors}
        {:error, reason} -> {shops, duplicates, sources, [{file, number, reason} | errors]}
      end
    end)
    |> then(fn {shops, duplicates, sources, errors} ->
      {Enum.reverse(shops), Enum.reverse(duplicates), Enum.reverse(sources), Enum.reverse(errors)}
    end)
  end

  @doc """
  Two-pass `duplicate(label)` resolve. Builds an `id -> items` map from the placed
  plain shops and fills each duplicate's items from it. Returns the combined shop
  list plus one drop-reason atom per unresolved duplicate, classified by the kind
  of source it targeted using `source_types` (`label -> :script | :cashshop`):

    * `:duplicate_of_script` - source is a `script` NPC (out of scope)
    * `:duplicate_of_cashshop` - source is a `cashshop` NPC (out of scope)
    * `:unknown_duplicate_source` - no matching source of any kind
  """
  @spec resolve_duplicates([shop_map()], [duplicate()], %{String.t() => Importer.source_type()}) ::
          {[shop_map()], [atom()]}
  def resolve_duplicates(shops, duplicates, source_types \\ %{}) do
    id_map = Map.new(shops, fn shop -> {shop["id"], Map.take(shop, ["items", "discount"])} end)

    {resolved, unresolved} =
      Enum.split_with(duplicates, fn {label, _partial} -> Map.has_key?(id_map, label) end)

    resolved_shops =
      Enum.map(resolved, fn {label, partial} -> Map.merge(partial, id_map[label]) end)

    reasons =
      Enum.map(unresolved, fn {label, _partial} -> unresolved_reason(source_types, label) end)

    {shops ++ resolved_shops, reasons}
  end

  @spec unresolved_reason(%{String.t() => Importer.source_type()}, String.t()) :: atom()
  defp unresolved_reason(source_types, label) do
    case Map.get(source_types, label) do
      :script -> :duplicate_of_script
      :cashshop -> :duplicate_of_cashshop
      nil -> :unknown_duplicate_source
    end
  end

  @spec sanitize([shop_map()]) :: {[shop_map()], [atom()], non_neg_integer()}
  defp sanitize(shops) do
    shops
    |> Enum.reduce({[], [], 0}, fn shop, {kept, skipped, dropped} ->
      case sanitize_shop(shop) do
        {:ok, clean, n} -> {[clean | kept], skipped, dropped + n}
        {:drop, reason, n} -> {kept, [reason | skipped], dropped + n}
      end
    end)
    |> then(fn {kept, skipped, dropped} ->
      {Enum.reverse(kept), Enum.reverse(skipped), dropped}
    end)
  end

  @spec sanitize_shop(shop_map()) ::
          {:ok, shop_map(), non_neg_integer()} | {:drop, atom(), non_neg_integer()}
  defp sanitize_shop(%{"map" => map, "x" => x, "y" => y} = shop) do
    cond do
      not MapCache.exists?(map) ->
        {:drop, :unknown_map, 0}

      not MapCache.walkable?(map, x, y) ->
        {:drop, :blocked_cell, 0}

      true ->
        {valid, invalid} = Enum.split_with(shop["items"], &item_known?/1)

        case valid do
          [] -> {:drop, :no_valid_items, length(invalid)}
          items -> {:ok, Map.put(shop, "items", items), length(invalid)}
        end
    end
  end

  @spec item_known?(map()) :: boolean()
  defp item_known?(%{"id" => nameid}) do
    match?({:ok, _}, ItemManagement.get_item_by_id(nameid))
  end

  @spec write!([shop_map()], Path.t()) :: :ok
  defp write!(kept, out_dir) do
    File.mkdir_p!(out_dir)
    clear_existing!(out_dir)

    kept
    |> Enum.group_by(& &1["map"])
    |> Enum.each(fn {map, shops} ->
      File.write!(Path.join(out_dir, "#{map}.yml"), Ymlr.document!(shops))
    end)
  end

  @spec clear_existing!(Path.t()) :: :ok
  defp clear_existing!(out_dir) do
    File.rm_rf!(Path.join(out_dir, ".cache"))
    out_dir |> Path.join("*.yml") |> Path.wildcard() |> Enum.each(&File.rm!/1)
    :ok
  end

  @spec report(
          [Path.t()],
          [shop_map()],
          [duplicate()],
          [shop_map()],
          [atom()],
          non_neg_integer(),
          [
            {Path.t(), pos_integer(), term()}
          ],
          Path.t()
        ) :: :ok
  defp report(files, shops, duplicates, kept, skipped, dropped_items, errors, out_dir) do
    maps = kept |> Enum.map(& &1["map"]) |> Enum.uniq() |> length()

    Mix.shell().info(
      "shops: parsed #{length(shops)} placed + #{length(duplicates)} duplicate lines " <>
        "from #{length(files)} files"
    )

    Mix.shell().info("  wrote #{length(kept)} across #{maps} maps -> #{out_dir}")

    unless skipped == [] do
      Mix.shell().info(
        "  skipped #{length(skipped)} to keep boot safe: #{inspect(freq(skipped))}"
      )
    end

    unless dropped_items == 0 do
      Mix.shell().info("  dropped #{dropped_items} phantom items from kept shops")
    end

    unless errors == [] do
      Mix.shell().error("  #{length(errors)} malformed lines (listed above)")
    end

    :ok
  end

  @spec freq([atom()]) :: %{atom() => non_neg_integer()}
  defp freq(reasons), do: Enum.frequencies(reasons)

  @spec report_error(Path.t(), pos_integer(), term()) :: :ok
  defp report_error(file, line, reason) do
    Mix.shell().error("  malformed #{file}:#{line} #{inspect(reason)}")
  end
end
