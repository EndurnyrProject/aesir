defmodule Aesir.ZoneServer.Mmo.Skill.Catalog do
  @moduledoc """
  Registry of skill definitions, loaded as data from `priv/db/skills/*.yml`.

  Built once via `Loader` and cached in `:persistent_term`; `reload/0` rebuilds
  it after the data files change in a long-running session.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Loader

  @pt_key __MODULE__

  @spec by_id(integer()) :: {:ok, Definition.t()} | :error
  def by_id(id), do: Map.fetch(index().by_id, id)

  @spec by_name(atom()) :: {:ok, Definition.t()} | :error
  def by_name(name), do: Map.fetch(index().by_name, name)

  @spec all() :: [Definition.t()]
  def all, do: index().all

  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, Loader.load(data_dir()))
    :ok
  end

  @spec index() :: Loader.index()
  defp index do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = Loader.load(data_dir())
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  @spec data_dir() :: Path.t()
  defp data_dir, do: Application.app_dir(:zone_server, "priv/db/skills")
end
