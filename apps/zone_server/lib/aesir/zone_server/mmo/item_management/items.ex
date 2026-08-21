defmodule Aesir.ZoneServer.Mmo.ItemManagement.Items do
  @moduledoc """
  Registry of item definitions, loaded as data from `priv/db/re/items/*.yml`.

  The id/aegis index is built once via `Loader` and cached in `:persistent_term`;
  `reload/0` rebuilds it after the data files change in a long-running session.
  Same API shape as `MobManagement.Mobs`, but aegis keys are strings (matching
  `MobDrop.item`).
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Loader

  @pt_key __MODULE__

  @spec by_id(integer()) :: {:ok, ItemDefinition.t()} | :error
  def by_id(id), do: Map.fetch(index().by_id, id)

  @spec by_aegis(String.t()) :: {:ok, ItemDefinition.t()} | :error
  def by_aegis(aegis), do: Map.fetch(index().by_aegis, aegis)

  @spec all() :: [ItemDefinition.t()]
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
  defp data_dir, do: Application.app_dir(:zone_server, "priv/db/re/items")
end
