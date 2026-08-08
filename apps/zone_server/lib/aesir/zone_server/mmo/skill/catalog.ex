defmodule Aesir.ZoneServer.Mmo.Skill.Catalog do
  @moduledoc """
  The single registry of skills.

  Discovers every skill module at runtime and indexes them two ways:

    * by definition - `by_id/1`, `by_name/1`, `all/0` for the interpreter and
      packet builders;
    * by capability - `active_module_for/1`, `ground_module_for/1`,
      `passive_module_for/1`, `passive_modules/0`, `menu_module_for/1`,
      `performance_module_for/1` from each module's `__skill_capabilities__/0`.

  Discovery walks the `:zone_server` application manifest and keeps the modules
  exporting `__skill_capabilities__/0`, which `use Skill` injects. Reading the
  manifest rather than the code server means modules defined in test files are
  structurally excluded, and the catalog does not recompile when a skill module
  changes. The indexes are built lazily on first access and cached in
  `:persistent_term`; `reload/0` rebuilds them after adding or editing skills in
  a long-running session.

  New skills are added by creating a module under `Aesir.ZoneServer.Mmo.Skills`
  that does `use Skill` - no registration step. Job namespaces and the
  `Aesir.ZoneServer.Mmo.Skills.Homunculus` namespace follow the same manifest
  convention, and absent future modules simply have no catalog entry. This
  replaces the former per-capability registries.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Requirement

  @pt_key __MODULE__

  @typep index :: %{
           all: [Definition.t()],
           by_id: %{integer() => Definition.t()},
           by_name: %{atom() => Definition.t()},
           requirements: %{integer() => [Requirement.t()]},
           active: %{atom() => module()},
           ground: %{atom() => module()},
           passive: %{atom() => module()},
           menu: %{atom() => module()},
           performance: %{atom() => module()},
           performance_ids: MapSet.t(integer()),
           ensemble: %{atom() => module()},
           ensemble_ids: MapSet.t(integer())
         }

  @spec all() :: [Definition.t()]
  def all, do: index().all

  @spec by_id(integer()) :: {:ok, Definition.t()} | :error
  def by_id(id), do: Map.fetch(index().by_id, id)

  @spec by_name(atom()) :: {:ok, Definition.t()} | :error
  def by_name(name), do: Map.fetch(index().by_name, name)

  @spec requirements_for(integer()) :: {:ok, [Requirement.t()]} | :error
  def requirements_for(id), do: Map.fetch(index().requirements, id)

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

  @spec performance_module_for(atom()) :: {:ok, module()} | :error
  def performance_module_for(name), do: Map.fetch(index().performance, name)

  @spec performance?(integer()) :: boolean()
  def performance?(id), do: MapSet.member?(index().performance_ids, id)

  @spec performance_ids() :: MapSet.t(integer())
  def performance_ids, do: index().performance_ids

  @spec ensemble?(integer()) :: boolean()
  def ensemble?(id), do: MapSet.member?(index().ensemble_ids, id)

  @spec replayable?(integer()) :: boolean()
  def replayable?(id), do: performance?(id) or ensemble?(id)

  @doc """
  The SP cost for `level` from a skill's `sp_cost` list, extrapolating past the
  defined level range instead of clamping.

  Mob skill rows routinely cast a skill above its player max level (e.g. Fire
  Bolt at level 48). Rather than yielding the top-of-list value, the last three
  entries project the linear trend for the requested level, matching how the
  reference engine derives high-level costs (Fire Bolt at 48 resolves to ~107
  rather than the level-10 30). Levels within range read directly. A list too
  short to project (fewer than three entries), a non-positive final entry, or an
  `:all`-priced level clamps to the nearest defined value; `:all` resolves to 0
  since it depends on live SP the caller must supply.
  """
  @spec sp_cost_at([non_neg_integer() | :all], pos_integer()) :: non_neg_integer()
  def sp_cost_at(sp_cost, level) when is_list(sp_cost) and level > 0 do
    cap = length(sp_cost)
    idx = min(level, cap) - 1

    with true <- level > cap and idx > 1,
         [a, b, c] when is_integer(a) and is_integer(b) and is_integer(c) and c > 1 <-
           Enum.slice(sp_cost, (idx - 2)..idx) do
      c + div((level - cap + 1) * (b - a), 2) + div((level - cap) * (c - b), 2)
    else
      _ -> clamp_sp_cost(Enum.at(sp_cost, idx, 0))
    end
  end

  defp clamp_sp_cost(:all), do: 0
  defp clamp_sp_cost(value) when is_integer(value), do: value
  defp clamp_sp_cost(_), do: 0

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
    performance = modules_with_capability(modules, :performance)
    ensemble = modules_with_capability(modules, :ensemble)

    performance_ids =
      for definition <- definitions,
          Map.has_key?(performance, definition.name),
          into: MapSet.new(),
          do: definition.id

    ensemble_ids =
      for definition <- definitions,
          Map.has_key?(ensemble, definition.name),
          into: MapSet.new(),
          do: definition.id

    %{
      all: definitions,
      by_id: Map.new(definitions, &{&1.id, &1}),
      by_name: Map.new(definitions, &{&1.name, &1}),
      requirements: Map.new(definitions, &{&1.id, &1.requires}),
      active: modules_with_capability(modules, :active),
      ground: modules_with_capability(modules, :ground),
      passive: modules_with_capability(modules, :passive),
      menu: modules_with_capability(modules, :menu),
      performance: performance,
      performance_ids: performance_ids,
      ensemble: ensemble,
      ensemble_ids: ensemble_ids
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
