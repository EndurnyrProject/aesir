defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrSlowpoison do
  @moduledoc """
  Slow Poison (PR_SLOWPOISON).

  rAthena Renewal: `db/re/skill_db.yml:2534-2564`. The status suspends Poison
  and Deadly Poison damage ticks while their natural-regeneration penalties are
  absent; it does not add arbitrary regeneration.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 71,
    name: :pr_slowpoison,
    status: :sc_slowpoison,
    display_name: "Slow Poison",
    max_level: 4,
    target_type: :target_ally,
    damage_kind: :magic,
    range: 9,
    sp_cost: [6, 8, 10, 12],
    duration: [10_000, 20_000, 30_000, 40_000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

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
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    apply_slow_poison(:player, caster_id, caster_id, level, definition, caster)
  end

  def cast(
        %{character_id: caster_id} = caster,
        {:unit, {unit_type, target_id} = target_ref},
        level,
        definition
      ) do
    with {:ok, %{unit_type: ^unit_type}} <- Combat.resolve_combatant(target_ref) do
      apply_slow_poison(unit_type, target_id, caster_id, level, definition, caster)
    end
  end

  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    with {:ok, %{unit_type: unit_type}} <- Combat.resolve_combatant(target_id) do
      apply_slow_poison(unit_type, target_id, caster_id, level, definition, caster)
    end
  end

  defp apply_slow_poison(unit_type, target_id, caster_id, level, definition, caster) do
    duration = Enum.at(definition.duration, level - 1)

    case StatusInterpreter.apply_status(unit_type, target_id, :sc_slowpoison,
           caster_id: caster_id,
           duration: duration
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
