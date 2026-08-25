defmodule Mix.Tasks.Aesir.Import do
  @moduledoc """
  Shared argument, source-path, and YAML helpers for rAthena import tasks.
  """

  alias Aesir.ZoneServer.Db.Layout

  @db_root Path.join(~w(apps zone_server priv db))

  @doc """
  Parses an optional rAthena root and `--mode re|pre-re` argument.

  The returned mode is the canonical atom consumed by the other helpers.
  """
  @spec parse!([String.t()]) :: {Path.t(), Layout.mode()}
  def parse!(args) do
    {options, paths, invalid} = OptionParser.parse(args, strict: [mode: :string])

    unless invalid == [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    mode =
      case Keyword.get(options, :mode, "re") do
        "re" -> :renewal
        "pre-re" -> :pre_renewal
        value -> Mix.raise("invalid --mode #{inspect(value)}; expected re or pre-re")
      end

    {List.first(paths) || "../rathena", mode}
  end

  @doc """
  Returns the mode-specific rAthena database directory.

  Pre-renewal's refine database is named `db/pre-re/refine.yml`, not
  `refine_db.yml`.
  """
  @spec rathena_db_dir(Path.t(), Layout.mode()) :: Path.t()
  def rathena_db_dir(rathena, mode),
    do: Path.join([rathena, "db", Layout.mode_dir(mode)])

  @doc """
  Reads a shared root rAthena YAML file and its selected official
  `Footer.Imports`.

  `path` must be a shared root file directly under `<rathena>/db`, such as
  `<rathena>/db/mob_db.yml`; do not pass a mode overlay path returned by
  `rathena_db_dir/2`. The checkout root is derived from this shared path.

  Import paths under `db/` are resolved against the rAthena checkout root and
  traversed depth-first in declaration order. Operator-local `db/import/`
  paths and generator imports are skipped. Import `Mode` must be the exact
  scalar `Renewal` or `Prerenewal`; untagged imports apply to both modes.

  Each file's `Body` rows are returned unchanged. In particular, `Mode` inside
  `Body` is data and is never interpreted by this helper. An absent `Body` is
  empty; a non-list `Body` raises.
  """
  @spec read_mode_filtered!(Path.t(), Layout.mode()) :: [term()]
  def read_mode_filtered!(path, mode) do
    path = Path.expand(path)
    checkout_root = path |> Path.dirname() |> Path.dirname()
    read_yaml!(path, checkout_root, rathena_mode(mode))
  end

  @doc "Returns an importer's output path for a database domain and mode."
  @spec path(Layout.domain(), Layout.mode()) :: Path.t()
  def path(domain, mode), do: Path.join(@db_root, Layout.rel_path(domain, mode))

  defp read_yaml!(path, checkout_root, target_mode) do
    {body, imports} = read_database!(path)

    imported_body =
      imports
      |> selected_imports(target_mode)
      |> Enum.flat_map(fn import_path ->
        read_yaml!(Path.join(checkout_root, import_path), checkout_root, target_mode)
      end)

    body ++ imported_body
  end

  defp read_database!(path) do
    case YamlElixir.read_from_file(path) do
      {:ok, yaml} ->
        validate_database!(yaml, path)

      {:error, %YamlElixir.FileNotFoundError{}} ->
        Mix.raise("missing rAthena YAML file #{path}")

      {:error, error} ->
        Mix.raise("failed to parse rAthena YAML file #{path}: #{Exception.message(error)}")
    end
  end

  defp validate_database!(yaml, path) when is_map(yaml) do
    validate_header!(yaml, path)
    {body!(yaml, path), imports!(yaml, path)}
  end

  defp validate_database!(_yaml, path), do: Mix.raise("expected top-level YAML map in #{path}")

  defp validate_header!(%{"Header" => header}, _path) when is_map(header), do: :ok
  defp validate_header!(_yaml, path), do: Mix.raise("expected Header to be a map in #{path}")

  defp body!(%{"Body" => body}, _path) when is_list(body), do: body
  defp body!(%{"Body" => _body}, path), do: Mix.raise("expected Body to be a list in #{path}")
  defp body!(_yaml, _path), do: []

  defp imports!(%{"Footer" => footer}, path) when is_map(footer) do
    case footer do
      %{"Imports" => imports} when is_list(imports) -> imports
      %{"Imports" => _imports} -> Mix.raise("expected Footer.Imports to be a list in #{path}")
      _footer -> []
    end
  end

  defp imports!(%{"Footer" => _footer}, path),
    do: Mix.raise("expected Footer to be a map in #{path}")

  defp imports!(_yaml, _path), do: []

  defp selected_imports(imports, target_mode) do
    imports
    |> Enum.filter(&selected_import?(&1, target_mode))
    |> Enum.map(& &1["Path"])
  end

  defp selected_import?(%{"Path" => "db/" <> _rest = path} = import, target_mode) do
    not local_import?(path) and import["Generator"] != true and mode_matches?(import, target_mode)
  end

  defp selected_import?(_import, _target_mode), do: false

  defp local_import?("db/import"), do: true
  defp local_import?("db/import/" <> _rest), do: true
  defp local_import?(_path), do: false

  defp mode_matches?(import, target_mode) do
    case Map.fetch(import, "Mode") do
      :error -> true
      {:ok, ^target_mode} -> true
      {:ok, _mode} -> false
    end
  end

  defp rathena_mode(:renewal), do: "Renewal"
  defp rathena_mode(:pre_renewal), do: "Prerenewal"
end
