defmodule Aesir.ZoneServer.Mmo.MobManagement.Mobs do
  @moduledoc """
  Registry of mob definitions, loaded as data from `priv/db/re/mobs/*.yml`.

  The id/name index is built once via `Loader` and cached in `:persistent_term`;
  `reload/0` rebuilds it after the data files change in a long-running session.
  Aegis names are strings (matching `MobDrop.item`).
  """

  alias Aesir.ZoneServer.Mmo.MobManagement.Loader
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition

  @pt_key __MODULE__

  @doc """
  Resolves a mob by its numeric id.
  """
  @spec by_id(integer()) :: {:ok, MobDefinition.t()} | :error
  def by_id(id), do: Map.fetch(index().by_id, id)

  @doc """
  Resolves a mob by its aegis name.
  """
  @spec by_name(String.t()) :: {:ok, MobDefinition.t()} | :error
  def by_name(name), do: Map.fetch(index().by_name, name)

  @doc """
  Returns all mob definitions.
  """
  @spec all() :: [MobDefinition.t()]
  def all, do: index().all

  @doc """
  Rebuilds the cached index after editing the data files in a running session.
  """
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
  defp data_dir, do: Application.app_dir(:zone_server, "priv/db/re/mobs")
end
