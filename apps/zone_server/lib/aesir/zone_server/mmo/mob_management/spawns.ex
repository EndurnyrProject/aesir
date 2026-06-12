defmodule Aesir.ZoneServer.Mmo.MobManagement.Spawns do
  @moduledoc """
  Registry of all per-map mob spawn modules.

  Spawn modules are auto-discovered at runtime (any module adopting
  `Aesir.ZoneServer.Mmo.MobManagement.Spawns.Definition`), so adding a map's
  spawns is just dropping a new module under `spawns/` — no list to maintain
  here. The resulting map-name index is built once and cached in
  `:persistent_term`; `reload/0` rebuilds it after recompiling spawn modules in a
  long-running session.
  """

  alias Aesir.ZoneServer.Mmo.MobManagement.Definition
  alias Aesir.ZoneServer.Mmo.MobManagement.Discovery
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns

  @app :zone_server
  @pt_key __MODULE__

  @doc """
  Returns all spawn definition modules.
  """
  @spec modules() :: [module()]
  def modules, do: index().modules

  @doc """
  Returns the spawn list for a given map.
  """
  @spec for_map(String.t()) :: {:ok, [MobSpawn.t()]} | :error
  def for_map(map_name), do: Map.fetch(index().by_map, map_name)

  @doc """
  Returns all spawn data, keyed by map name.
  """
  @spec all() :: %{String.t() => [MobSpawn.t()]}
  def all, do: index().by_map

  @doc """
  Rebuilds the cached index. Use after recompiling spawn modules in a running
  session; not needed in normal operation.
  """
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, build())
    :ok
  end

  @doc """
  Validates that every mob referenced by `module`'s spawns is a mob
  definition module. Raises `ArgumentError` otherwise.
  """
  @spec validate_mob_refs!(module()) :: :ok
  def validate_mob_refs!(module) do
    Enum.each(module.spawns(), fn %MobSpawn{mob: mob} ->
      if not Discovery.adopts?(mob, Definition) do
        raise ArgumentError,
              "spawn module #{inspect(module)} (map #{module.map_name()}) references " <>
                "#{inspect(mob)}, which is not a mob definition module"
      end
    end)
  end

  @spec index() :: map()
  defp index do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = build()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  @spec build() :: map()
  defp build do
    modules = Discovery.modules_for(@app, Spawns.Definition)
    Enum.each(modules, &validate_mob_refs!/1)

    %{
      modules: modules,
      by_map: Map.new(modules, &{&1.map_name(), &1.spawns()})
    }
  end
end
