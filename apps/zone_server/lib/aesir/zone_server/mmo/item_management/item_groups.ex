defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups do
  @moduledoc """
  Registry of item groups loaded from `priv/db/re/item_groups/*.yml`.

  The key index is built once via `Loader` and cached in `:persistent_term`;
  `reload/0` rebuilds it after the data files change in a long-running session.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Loader

  @pt_key __MODULE__

  @doc "Resolves an item group by its atom key."
  @spec fetch(atom()) :: {:ok, Group.t()} | :error
  def fetch(key), do: Map.fetch(index(), key)

  @doc "Whether an item appears in any subgroup of the named item group."
  @spec member?(atom(), pos_integer()) :: boolean()
  def member?(key, item_id) do
    case fetch(key) do
      {:ok, group} ->
        Enum.any?(group.subgroups, fn subgroup ->
          Enum.any?(subgroup.entries, &(&1.item_id == item_id))
        end)

      :error ->
        false
    end
  end

  @doc "Returns runtime readiness only; it does not identify the catalog's game mode."
  @spec loaded?() :: boolean()
  def loaded?, do: not is_nil(:persistent_term.get(@pt_key, nil))

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
