defmodule Aesir.ZoneServer.Mmo.Skill.Catalog do
  @moduledoc """
  The single registry of skills.

  Lists every skill module once and indexes them two ways at runtime:

    * by definition - `by_id/1`, `by_name/1`, `all/0` for the interpreter and
      packet builders;
    * by capability - `active_module_for/1`, `ground_module_for/1`,
      `passive_module_for/1`, `passive_modules/0` from each module's
      `__skill_capabilities__/0`.

  The `@skills` list is only a runtime reference to each module, so editing a
  skill module does not recompile the catalog (or its dependents). The indexes
  are built lazily on first access and cached in `:persistent_term`; `reload/0`
  rebuilds them after adding or editing skills in a long-running session.

  New skills are added by creating a module under `Aesir.ZoneServer.Mmo.Skills`
  and listing it here. This replaces the former per-capability registries.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills

  @pt_key __MODULE__

  @skills [
    Skills.AcChargearrow,
    Skills.AcConcentration,
    Skills.AcDouble,
    Skills.AcMakingarrow,
    Skills.AcOwl,
    Skills.AcShower,
    Skills.AcVulture,
    Skills.AlAngelus,
    Skills.AlBlessing,
    Skills.AlCrucis,
    Skills.AlCure,
    Skills.AlDecagi,
    Skills.AlDemonbane,
    Skills.AlDp,
    Skills.AlHeal,
    Skills.AlHolylight,
    Skills.AlHolywater,
    Skills.AlIncagi,
    Skills.AlPneuma,
    Skills.AlRuwach,
    Skills.AlTeleport,
    Skills.AlWarp,
    Skills.HtBlastmine,
    Skills.HtLandmine,
    Skills.McInccarry,
    Skills.McLoud,
    Skills.McMammonite,
    Skills.McCartrevolution,
    Skills.McChangecart,
    Skills.McPushcart,
    Skills.McVending,
    Skills.MgColdbolt,
    Skills.MgEnergycoat,
    Skills.MgFireball,
    Skills.MgFirebolt,
    Skills.MgFirewall,
    Skills.MgFrostdiver,
    Skills.MgLightningbolt,
    Skills.MgNapalmbeat,
    Skills.MgSafetywall,
    Skills.MgSight,
    Skills.MgSoulstrike,
    Skills.MgSrecovery,
    Skills.MgStonecurse,
    Skills.MgThunderstorm,
    Skills.NvBasic,
    Skills.NvFirstaid,
    Skills.NvTrickdead,
    Skills.SmAutoberserk,
    Skills.SmBash,
    Skills.SmEndure,
    Skills.SmFatalblow,
    Skills.SmMagnum,
    Skills.SmMovingRecovery,
    Skills.SmProvoke,
    Skills.SmRecovery,
    Skills.SmSword,
    Skills.SmTwohand,
    Skills.TfBacksliding,
    Skills.TfDetoxify,
    Skills.TfDouble,
    Skills.TfHiding,
    Skills.TfMiss,
    Skills.TfPickstone,
    Skills.TfPoison,
    Skills.TfSprinklesand,
    Skills.TfSteal,
    Skills.TfThrowstone,
    Skills.WzEarthspike,
    Skills.WzFirepillar,
    Skills.WzFrostnova,
    Skills.WzHeavendrive,
    Skills.WzIcewall,
    Skills.WzJupitel,
    Skills.WzMeteor,
    Skills.WzQuagmire,
    Skills.WzSightrasher,
    Skills.WzStormgust,
    Skills.WzWaterball,
    Skills.WzVermilion
  ]

  @typep index :: %{
           all: [Definition.t()],
           by_id: %{integer() => Definition.t()},
           by_name: %{atom() => Definition.t()},
           active: %{atom() => module()},
           ground: %{atom() => module()},
           passive: %{atom() => module()}
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
    definitions = Enum.map(@skills, & &1.definition())

    %{
      all: definitions,
      by_id: Map.new(definitions, &{&1.id, &1}),
      by_name: Map.new(definitions, &{&1.name, &1}),
      active: modules_with_capability(:active),
      ground: modules_with_capability(:ground),
      passive: modules_with_capability(:passive)
    }
  end

  @spec modules_with_capability(atom()) :: %{atom() => module()}
  defp modules_with_capability(capability) do
    for module <- @skills, capability in module.__skill_capabilities__(), into: %{} do
      {module.skill_name(), module}
    end
  end
end
