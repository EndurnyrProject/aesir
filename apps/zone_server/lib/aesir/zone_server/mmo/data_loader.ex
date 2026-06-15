defmodule Aesir.ZoneServer.Mmo.DataLoader do
  @moduledoc """
  Shared loader for our-schema YAML game data (items, mobs, spawns).

  Globs every `*.yml` in a directory and turns it into a cached term via the
  caller's `build_fn`. A compact `.etf` cache under `<dir>/.cache/` is reused
  while it is newer than every source file, so warm boots skip YAML parsing
  entirely. Plain functions only - no process.
  """

  @cache_dir ".cache"

  @doc """
  Returns the built term for `dir`, reading the cache when fresh.

  `build_fn` receives the source `*.yml` paths and must return the term to cache;
  it is only called on a cache miss. `cache_file` is the cache basename, e.g.
  `"mobs.etf"`.
  """
  @spec load(Path.t(), String.t(), ([Path.t()] -> term())) :: term()
  def load(dir, cache_file, build_fn) do
    sources = dir |> Path.join("*.yml") |> Path.wildcard()

    if sources == [] do
      raise "no data files in #{dir}"
    end

    cache = Path.join([dir, @cache_dir, cache_file])

    if cache_fresh?(cache, sources) do
      cache |> File.read!() |> :erlang.binary_to_term()
    else
      built = build_fn.(sources)
      write_cache!(cache, built)
      built
    end
  end

  @doc """
  Parses a single YAML file into its top-level list of maps.
  """
  @spec parse_file(Path.t()) :: [map()]
  def parse_file(path), do: YamlElixir.read_from_file!(path)

  @spec cache_fresh?(Path.t(), [Path.t()]) :: boolean()
  defp cache_fresh?(cache, sources) do
    File.exists?(cache) and mtime(cache) >= sources |> Enum.map(&mtime/1) |> Enum.max()
  end

  @spec mtime(Path.t()) :: integer()
  defp mtime(path), do: File.stat!(path, time: :posix).mtime

  @spec write_cache!(Path.t(), term()) :: :ok
  defp write_cache!(cache, built) do
    File.mkdir_p!(Path.dirname(cache))
    File.write!(cache, :erlang.term_to_binary(built))
  end
end
