defmodule Aesir.ZoneServer.Mmo.MobManagement.Mobs do
  @moduledoc """
  Registry of mob definitions, loaded as data from `priv/db/re/mobs/*.yml`.

  The id/name index is built once via `Loader` and cached in `:persistent_term`;
  `reload/0` rebuilds it after the data files change in a long-running session.
  Aegis names are strings (matching `MobDrop.item`).
  """

  alias Aesir.ZoneServer.Mmo.MobManagement.Loader
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns

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
  Resolves a monster name as a script's monster argument does: the id of a
  monster whose aegis name, or (for a monster with experience or a
  spawn) whose name or Japanese name, cut to its first 24 characters, equals
  `name` case-insensitively, or 0. Clone ids never match. When several
  monsters match, the lowest id wins (the reference's pick follows its hash
  table's order, which no id order reproduces).
  """
  @spec search_name(String.t()) :: non_neg_integer()
  def search_name(name), do: search_name(name, all(), spawned_ids())

  @doc "`search_name/1` over the given monsters and spawned monster ids."
  @spec search_name(String.t(), [MobDefinition.t()], MapSet.t(integer())) :: non_neg_integer()
  def search_name(name, mobs, spawned) do
    key = String.downcase(name, :ascii)

    mobs
    |> Enum.sort_by(& &1.id)
    |> Enum.find_value(0, fn mob -> if name_match?(mob, key, spawned), do: mob.id end)
  end

  @clone_ids 3_999..20_020

  defp name_match?(%MobDefinition{id: id}, _key, _spawned) when id in @clone_ids, do: false

  defp name_match?(mob, key, spawned) do
    name_key(mob.aegis_name) == key or
      ((mob.base_exp != 0 or mob.job_exp != 0 or MapSet.member?(spawned, mob.id)) and
         key in [name_key(mob.name), name_key(mob.japanese_name || mob.name)])
  end

  defp name_key(name),
    do: name |> binary_part(0, min(byte_size(name), 24)) |> String.downcase(:ascii)

  defp spawned_ids do
    for {_map, spawns} <- Spawns.all(), spawn <- spawns, into: MapSet.new(), do: spawn.mob
  end

  @doc """
  The drop table a monster of `definition`'s kind drops from and can be stolen
  from now: its kind's table as a script last edited it (`put_drops/2`), even
  for a monster spawned before the edit, otherwise the table it spawned with.
  """
  @spec current_drops(MobDefinition.t()) :: [MobDrop.t()]
  def current_drops(%MobDefinition{id: id, drops: drops}) do
    index = index()

    if MapSet.member?(index.edited_drops, id),
      do: Map.fetch!(index.by_id, id).drops,
      else: drops
  end

  @doc """
  Edits monster `mob_id`'s drop table with `update` (current table in, new
  table or `:unchanged` out), for scripts that edit monster drops while the
  server runs; every monster of that kind drops from the edited table from
  then on. Edits are serialized, each reading the table the previous one
  wrote. Returns `update`'s result.
  """
  @spec update_drops(integer(), ([MobDrop.t()] -> {:ok, [MobDrop.t()]} | term())) :: term()
  def update_drops(mob_id, update) do
    :global.trans({__MODULE__, :edit}, fn ->
      index = index()
      mob = Map.fetch!(index.by_id, mob_id)

      with {:ok, drops} <- update.(mob.drops) do
        put_mob(index, %{mob | drops: drops})
        {:ok, drops}
      end
    end)
  end

  @doc "Replaces monster `mob_id`'s drop table (`update_drops/2` with a constant table)."
  @spec put_drops(integer(), [MobDrop.t()]) :: :ok
  def put_drops(mob_id, drops) do
    {:ok, _drops} = update_drops(mob_id, fn _current -> {:ok, drops} end)
    :ok
  end

  defp put_mob(index, mob) do
    :persistent_term.put(@pt_key, %{
      index
      | by_id: Map.put(index.by_id, mob.id, mob),
        by_name: Map.put(index.by_name, mob.aegis_name, mob),
        all: Enum.map(index.all, &if(&1.id == mob.id, do: mob, else: &1)),
        edited_drops: MapSet.put(index.edited_drops, mob.id)
    })
  end

  @doc """
  Rebuilds the cached index after editing the data files in a running session.
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
