defmodule Aesir.ZoneServer.Mmo.Skill.Catalog do
  @moduledoc """
  The single registry of skills.

  Lists every skill module once and indexes them two ways at compile time:

    * by definition - `by_id/1`, `by_name/1`, `all/0` for the interpreter and
      packet builders;
    * by capability - `active_module_for/1`, `ground_module_for/1`,
      `passive_module_for/1`, `passive_modules/0` from each module's
      `__skill_capabilities__/0`.

  New skills are added by creating a module under `Aesir.ZoneServer.Mmo.Skills`
  and listing it here. This replaces the former per-capability registries.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills

  @skills [
    Skills.AlIncagi,
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
    Skills.WzStormgust
  ]

  @definitions for module <- @skills, do: module.definition()
  @by_id Map.new(@definitions, &{&1.id, &1})
  @by_name Map.new(@definitions, &{&1.name, &1})

  @active (for module <- @skills, :active in module.__skill_capabilities__(), into: %{} do
             {module.skill_name(), module}
           end)

  @ground (for module <- @skills, :ground in module.__skill_capabilities__(), into: %{} do
             {module.skill_name(), module}
           end)

  @passive (for module <- @skills, :passive in module.__skill_capabilities__(), into: %{} do
              {module.skill_name(), module}
            end)

  @spec all() :: [Definition.t()]
  def all, do: @definitions

  @spec by_id(integer()) :: {:ok, Definition.t()} | :error
  def by_id(id), do: Map.fetch(@by_id, id)

  @spec by_name(atom()) :: {:ok, Definition.t()} | :error
  def by_name(name), do: Map.fetch(@by_name, name)

  @spec active_module_for(atom()) :: {:ok, module()} | :error
  def active_module_for(name), do: Map.fetch(@active, name)

  @spec ground_module_for(atom()) :: {:ok, module()} | :error
  def ground_module_for(name), do: Map.fetch(@ground, name)

  @spec passive_module_for(atom()) :: {:ok, module()} | :error
  def passive_module_for(name), do: Map.fetch(@passive, name)

  @spec passive_modules() :: [module()]
  def passive_modules, do: Map.values(@passive)
end
