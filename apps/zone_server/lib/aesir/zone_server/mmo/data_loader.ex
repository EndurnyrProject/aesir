defmodule Aesir.ZoneServer.Mmo.DataLoader do
  @moduledoc """
  Shared loader for our-schema YAML game data.

  Resolves each database domain into sorted base sources followed by sorted import
  overlay sources, then turns them into a cached term via the caller's `build_fn`.
  A compact `.etf` cache under the domain's base `.cache/` directory is reused
  while its source list is unchanged and it is newer than every source file.
  Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Db.Layout
  alias Aesir.ZoneServer.Db.Source

  @cache_dir ".cache"

  @doc """
  Returns the built term for `domain`, reading the cache when fresh.

  `build_fn` receives the ordered base and import source paths and must return the
  term to cache; it is only called on a cache miss. `cache_file` is the cache
  basename, e.g. `"mobs.etf"`.
  """
  @spec load(Layout.domain(), String.t(), ([Path.t()] -> term())) :: term()
  def load(domain, cache_file, build_fn) do
    sources = Source.sources(domain)
    cache = Path.join([Source.base_dir(domain), @cache_dir, cache_file])

    with {:ok, binary} <- File.read(cache),
         %{sources: ^sources, term: term} <- :erlang.binary_to_term(binary),
         true <- mtime(cache) >= max_mtime(sources) do
      term
    else
      _ ->
        built = build_fn.(sources)
        write_cache!(cache, %{sources: sources, term: built})
        built
    end
  end

  @doc "Last entry wins per key while first-occurrence order is preserved."
  @spec merge_by_key([entry], (entry -> term())) :: [entry] when entry: term()
  def merge_by_key(entries, key_fn) do
    {index, order} =
      Enum.reduce(entries, {%{}, []}, fn entry, {index, order} ->
        key = key_fn.(entry)
        order = if Map.has_key?(index, key), do: order, else: [key | order]
        {Map.put(index, key, entry), order}
      end)

    order |> Enum.reverse() |> Enum.map(&Map.fetch!(index, &1))
  end

  @doc """
  Parses a single YAML file into its top-level list of maps.
  """
  @spec parse_file(Path.t()) :: [map()]
  def parse_file(path), do: YamlElixir.read_from_file!(path)

  @spec max_mtime([Path.t()]) :: integer()
  defp max_mtime(sources), do: sources |> Enum.map(&mtime/1) |> Enum.max()

  @spec mtime(Path.t()) :: integer()
  defp mtime(path), do: File.stat!(path, time: :posix).mtime

  @spec write_cache!(Path.t(), term()) :: :ok
  defp write_cache!(cache, blob) do
    File.mkdir_p!(Path.dirname(cache))
    File.write!(cache, :erlang.term_to_binary(blob))
  end
end
