defmodule Aesir.ZoneServer.Mmo.Woe.CastleDb do
  @moduledoc """
  Catalog of the 20 WoE First-Edition castles, loaded as data from
  `priv/db/re/castles/fe.yml`.

  The id/map index is built once via `Loader` and cached in `:persistent_term`;
  `reload/0` rebuilds it after the data file changes in a long-running session.
  """

  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Loader

  @pt_key __MODULE__

  @doc """
  Resolves a castle by its numeric id.
  """
  @spec by_id(non_neg_integer()) :: {:ok, Castle.t()} | :error
  def by_id(id), do: Map.fetch(index().by_id, id)

  @doc """
  Resolves a castle by its map name.
  """
  @spec by_map(String.t()) :: {:ok, Castle.t()} | :error
  def by_map(map), do: Map.fetch(index().by_map, map)

  @doc """
  Returns all castles.
  """
  @spec all() :: [Castle.t()]
  def all, do: index().all

  @doc """
  Rebuilds the cached index after editing the data file in a running session.
  """
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, Loader.load())
    :ok
  end

  @spec index() :: Loader.index()
  defp index do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = Loader.load()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end
end
