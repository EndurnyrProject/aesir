defmodule Aesir.ZoneServer.Mmo.QuestManagement.Quests do
  @moduledoc """
  Registry of quest definitions, loaded as data from `priv/db/re/quests/*.yml`.

  The id index is built once via `Loader` and cached in `:persistent_term`;
  `reload/0` rebuilds it after the data files change in a long-running session.
  Same shape as `ItemManagement.Items`.
  """

  alias Aesir.ZoneServer.Mmo.QuestManagement.Loader
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition

  @pt_key __MODULE__

  @doc """
  Resolves a quest by its numeric id.
  """
  @spec by_id(integer()) :: {:ok, QuestDefinition.t()} | :error
  def by_id(id), do: Map.fetch(index().by_id, id)

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
  defp data_dir, do: Application.app_dir(:zone_server, "priv/db/re/quests")
end
