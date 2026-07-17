defmodule Aesir.ZoneServer.Mmo.Skill.Catalog do
  @moduledoc """
  The single registry of skills.

  Discovers every skill module at runtime and indexes them two ways:

    * by definition - `by_id/1`, `by_name/1`, `all/0` for the interpreter and
      packet builders;
    * by capability - `active_module_for/1`, `ground_module_for/1`,
      `passive_module_for/1`, `passive_modules/0`, `menu_module_for/1` from each
      module's `__skill_capabilities__/0`.

  Discovery walks the `:zone_server` application manifest and keeps the modules
  exporting `__skill_capabilities__/0`, which `use Skill` injects. Reading the
  manifest rather than the code server means modules defined in test files are
  structurally excluded, and the catalog does not recompile when a skill module
  changes. The indexes are built lazily on first access and cached in
  `:persistent_term`; `reload/0` rebuilds them after adding or editing skills in
  a long-running session.

  New skills are added by creating a module under `Aesir.ZoneServer.Mmo.Skills`
  that does `use Skill` - no registration step. This replaces the former
  per-capability registries.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @pt_key __MODULE__

  @typep index :: %{
           all: [Definition.t()],
           by_id: %{integer() => Definition.t()},
           by_name: %{atom() => Definition.t()},
           active: %{atom() => module()},
           ground: %{atom() => module()},
           passive: %{atom() => module()},
           menu: %{atom() => module()}
         }

  @spec all() :: [Definition.t()]
  def all, do: index().all

  @spec by_id(integer()) :: {:ok, Definition.t()} | :error
  def by_id(id), do: Map.fetch(index().by_id, id)

  @spec by_name(atom()) :: {:ok, Definition.t()} | :error
  def by_name(name), do: Map.fetch(index().by_name, name)

  @spec active_module_for(atom()) :: {:ok, module()} | :error
  def active_module_for(name), do: Map.fetch(index().active, name)

  @spec ground_module_for(atom()) :: {:ok, module()} | :error
  def ground_module_for(name), do: Map.fetch(index().ground, name)

  @spec passive_module_for(atom()) :: {:ok, module()} | :error
  def passive_module_for(name), do: Map.fetch(index().passive, name)

  @spec passive_modules() :: [module()]
  def passive_modules, do: Map.values(index().passive)

  @spec menu_module_for(atom()) :: {:ok, module()} | :error
  def menu_module_for(name), do: Map.fetch(index().menu, name)

  @doc """
  Rebuilds the cached index after adding or editing skills in a running session.
  """
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, build())
    :ok
  end

  @spec index() :: index()
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

  @spec build() :: index()
  defp build do
    modules = discover()
    definitions = modules |> Enum.map(& &1.definition()) |> Enum.sort_by(& &1.id)

    %{
      all: definitions,
      by_id: Map.new(definitions, &{&1.id, &1}),
      by_name: Map.new(definitions, &{&1.name, &1}),
      active: modules_with_capability(modules, :active),
      ground: modules_with_capability(modules, :ground),
      passive: modules_with_capability(modules, :passive),
      menu: modules_with_capability(modules, :menu)
    }
  end

  @spec discover() :: [module()]
  defp discover do
    {:ok, modules} = :application.get_key(:zone_server, :modules)

    Enum.filter(modules, fn module ->
      Code.ensure_loaded?(module) and function_exported?(module, :__skill_capabilities__, 0)
    end)
  end

  @spec modules_with_capability([module()], atom()) :: %{atom() => module()}
  defp modules_with_capability(modules, capability) do
    for module <- modules, capability in module.__skill_capabilities__(), into: %{} do
      {module.skill_name(), module}
    end
  end
end
