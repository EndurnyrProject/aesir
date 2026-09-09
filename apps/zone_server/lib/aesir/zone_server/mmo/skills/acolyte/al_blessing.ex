defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlBlessing do
  @moduledoc """
  Blessing (AL_BLESSING). Applies SC_BLESSING to an ally: STR, INT and DEX up by
  the skill level, for a minute at level 1 growing by twenty seconds per level.

  The status module handles the curse veto and the stone cure: cast on a cursed
  target the buff is spent removing the curse instead, and cast on a petrified
  one it cures the petrification. Demon race targets and targets whose defence
  element is undead (the default detection mode; race alone does not count)
  receive `val2 = 0`, which the status reads as the
  hostile case and halves those stats instead of raising them. A player target is
  always treated as friendly, never halved.

  Renewal: instant cast, no after-cast delay, range nine. The buff also grants
  HIT equal to twice the skill level, to a hostile recipient as much as a
  friendly one.

  Pre-renewal: the same cast, cost, range, stat changes and durations, and no
  HIT bonus at all.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 34,
    name: :al_blessing,
    requires: [],
    status: :sc_blessing,
    display_name: "Blessing",
    max_level: 10,
    target_type: :target_ally,
    damage_kind: :magic,
    range: 9,
    sp_cost: [28, 32, 36, 40, 44, 48, 52, 56, 60, 64],
    duration: [
      60_000,
      80_000,
      100_000,
      120_000,
      140_000,
      160_000,
      180_000,
      200_000,
      220_000,
      240_000
    ]

  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def validate(%{character_id: caster_id}, {:unit, {:homunculus, gid}}, _level, _definition) do
    with {:ok, caster_combatant} <- TargetResolver.resolve_combatant(:player, caster_id),
         {:ok, target_combatant} <- TargetResolver.resolve_combatant(:homunculus, gid),
         true <- Targeting.direct_support?(caster_combatant, target_combatant) do
      :ok
    else
      _ -> {:error, :invalid_target}
    end
  end

  def validate(_caster, {:unit, {:homunculus, _gid}}, _level, _definition),
    do: {:error, :invalid_target}

  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, target, level, definition) do
    caster_id = Active.caster_unit_id(caster)
    target_id = Active.resolve_target_id(caster, target)
    duration = Enum.at(definition.duration, level - 1)

    with {:ok, unit_type, unit_id, val2} <- target_status_params(target, target_id, level) do
      params = [val1: level, val2: val2, caster_id: caster_id, duration: duration]

      # NOTE: Aesir has no SC_CHANGEUNDEAD player misc-attack path. When it exists, add
      # Blessing's transformed-player removal/attack branch and remove this note.
      case StatusInterpreter.apply_status(unit_type, unit_id, :sc_blessing, params) do
        :ok -> {:ok, caster}
        {:error, _reason} = error -> error
      end
    end
  end

  defp target_status_params(:self, target_id, level), do: {:ok, :player, target_id, level}

  defp target_status_params({:unit, {unit_type, unit_id}}, _target_id, level) do
    with {:ok, combatant} <- TargetResolver.resolve_combatant(unit_type, unit_id) do
      val2 = if undead_or_demon?(combatant), do: 0, else: level
      {:ok, unit_type, unit_id, val2}
    end
  end

  defp target_status_params(_target, target_id, level) do
    if UnitRegistry.unit_exists?(:mob, target_id) do
      mob_status_params(target_id, level)
    else
      {:ok, :player, target_id, level}
    end
  end

  defp mob_status_params(target_id, level) do
    case TargetResolver.resolve_combatant(:mob, target_id) do
      {:ok, combatant} ->
        val2 = if undead_or_demon?(combatant), do: 0, else: level
        {:ok, :mob, target_id, val2}

      {:error, _reason} = error ->
        error
    end
  end

  defp undead_or_demon?(combatant) do
    RaceModifiers.undead_target?(combatant) or Map.get(combatant, :race) == :demon
  end
end
