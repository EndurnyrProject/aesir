defmodule Aesir.ZoneServer.Mmo.MobManagement.Mobs do
  @moduledoc """
  Registry of all mob definition modules.

  Mob modules are auto-discovered at runtime (any module adopting
  `Aesir.ZoneServer.Mmo.MobManagement.Definition`), so adding a mob is just
  dropping a new module under `mobs/` — no list to maintain here. The resulting
  id/name index is built once and cached in `:persistent_term`; `reload/0`
  rebuilds it after recompiling mob modules in a long-running session.
  """

  alias Aesir.ZoneServer.Mmo.MobManagement.Definition
  alias Aesir.ZoneServer.Mmo.MobManagement.Discovery
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition

  @app :zone_server
  @pt_key __MODULE__

  @doc """
  Returns all mob definition modules.
  """
  @spec modules() :: [module()]
  def modules, do: index().modules

  @doc """
  Resolves a mob by its numeric id.
  """
  @spec by_id(integer()) :: {:ok, MobDefinition.t()} | :error
  def by_id(id), do: Map.fetch(index().by_id, id)

  @doc """
  Resolves a mob by its aegis name.
  """
  @spec by_name(atom()) :: {:ok, MobDefinition.t()} | :error
  def by_name(name), do: Map.fetch(index().by_name, name)

  @doc """
  Returns all mob definitions.
  """
  @spec all() :: [MobDefinition.t()]
  def all, do: index().all

  @doc """
  Rebuilds the cached index. Use after recompiling mob modules in a running
  session; not needed in normal operation.
  """
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, build())
    :ok
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
    modules = Discovery.modules_for(@app, Definition)
    mobs = Enum.map(modules, & &1.mob())

    %{
      modules: modules,
      all: mobs,
      by_id: Map.new(mobs, &{&1.id, &1}),
      by_name: Map.new(mobs, &{&1.aegis_name, &1})
    }
  end
end
