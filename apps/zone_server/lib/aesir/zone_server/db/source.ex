defmodule Aesir.ZoneServer.Db.Source do
  @moduledoc """
  Resolves database source files for the active mode.
  """

  alias Aesir.ZoneServer.Db.Layout

  @doc "Returns the active database mode."
  @spec mode() :: Layout.mode()
  defdelegate mode, to: Aesir.Commons.GameMode

  @doc """
  Returns ordered base and import source files for a database domain.

  Returns an empty list when the domain is not available in the active mode.
  """
  @spec sources(Layout.domain()) :: [Path.t()]
  def sources(domain) do
    modes = Layout.modes(domain)

    if mode() in modes do
      {base, import} = source_paths(domain)

      if base == [] do
        missing_data!(domain)
      else
        Enum.sort(base) ++ Enum.sort(import)
      end
    else
      []
    end
  end

  @doc "Returns the base directory used as a cache anchor for a database domain."
  @spec base_dir(Layout.domain()) :: Path.t()
  def base_dir(domain) do
    path = base_path(domain)
    if Layout.kind(domain) == :glob, do: path, else: Path.dirname(path)
  end

  @spec source_paths(Layout.domain()) :: {[Path.t()], [Path.t()]}
  defp source_paths(domain) do
    base_path = base_path(domain)
    import_path = import_path(domain)

    case Layout.kind(domain) do
      :glob ->
        {Path.wildcard(Path.join(base_path, "*.yml")),
         Path.wildcard(Path.join(import_path, "*.yml"))}

      :file ->
        {existing_file(base_path), existing_file(import_path)}
    end
  end

  @spec existing_file(Path.t()) :: [Path.t()]
  defp existing_file(path), do: if(File.exists?(path), do: [path], else: [])

  @spec missing_data!(Layout.domain()) :: no_return()
  defp missing_data!(domain) do
    expected_path = Path.join("priv/db", Layout.rel_path(domain, mode()))

    case Layout.import_task(domain) do
      nil ->
        raise "no #{mode()} data for db #{inspect(domain)} (expected under #{expected_path}). " <>
                "This database is hand-authored and has no importer; add its base YAML or set AESIR_DB_MODE=renewal."

      task ->
        raise "no #{mode()} data for db #{inspect(domain)} (expected under #{expected_path}). " <>
                "Import it with `mix #{task}` or set AESIR_DB_MODE=renewal."
    end
  end

  @spec base_path(Layout.domain()) :: Path.t()
  defp base_path(domain), do: Path.join(db_root(), Layout.rel_path(domain, mode()))

  @spec import_path(Layout.domain()) :: Path.t()
  defp import_path(domain), do: Path.join(db_root(), Layout.import_rel_path(domain))

  @spec db_root() :: Path.t()
  defp db_root do
    Application.get_env(:zone_server, :db_root, Application.app_dir(:zone_server, "priv/db"))
  end
end
