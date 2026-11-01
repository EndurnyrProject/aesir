defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcCriticalwound do
  @moduledoc """
  Critical Wounds strikes once for 100% weapon damage in the weapon's element,
  without a critical or an accuracy bonus. A connecting hit attempts Critical
  Wound at 100% base chance for 30 seconds through ordinary status defense.

  Identical in both modes. Players can trigger it through equipment and mobs
  cast it through their skill rows; the declared cast range is seven cells.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 673,
    name: :npc_criticalwound,
    display_name: "Critical Wounds",
    max_level: 5,
    requires: [],
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :weapon,
    range: -7,
    is_npc: true,
    duration: List.duplicate(30_000, 5),
    status: :sc_criticalwound

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100,
      skip_crit: true,
      skip_range: true,
      report_hit: true
    ]

    case Combat.execute_skill_attack(caster, target, opts) do
      {:ok, %{hit?: true}} ->
        apply_wound(caster, target, level, definition)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp apply_wound(caster, {type, id}, level, definition) do
    adapter = Caster.for(caster)

    StatusInterpreter.apply_status(type, id, definition.status,
      val1: level,
      duration: Enum.at(definition.duration, level - 1, List.last(definition.duration)),
      success_rate: 100,
      caster_id: adapter.id(caster),
      source_type: adapter.unit_type(caster)
    )
  end

  defp apply_wound(caster, id, level, definition) do
    case UnitRegistry.unit_type_for(id) do
      {:ok, type} -> apply_wound(caster, {type, id}, level, definition)
      {:error, _reason} -> :ok
    end
  end
end
