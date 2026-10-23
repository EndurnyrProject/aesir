defmodule Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions do
  @moduledoc """
  Catalog of item random options and random option groups, loaded from the
  active mode's `random_options` data.

  The index is built once via `Loader` and cached in `:persistent_term`;
  `reload/0` rebuilds it after the data files change in a running session.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Loader
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Option

  @pt_key __MODULE__

  @doc "Resolves a random option by id."
  @spec option(integer()) :: {:ok, Option.t()} | :error
  def option(id), do: Map.fetch(index().options, id)

  @doc "Resolves a random option group by id."
  @spec group(integer()) :: {:ok, Group.t()} | :error
  def group(id), do: Map.fetch(index().groups, id)

  @doc "Returns every random option group, by id."
  @spec groups() :: %{pos_integer() => Group.t()}
  def groups, do: index().groups

  @doc "Rebuilds the cached index after editing the data files in a running session."
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
