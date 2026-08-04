defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfDetoxify do
  @moduledoc """
  Detoxify (TF_DETOXIFY). Removes Poison and Deadly Poison from an ally.

  rAthena: id 53, max level 1, SP 10, range 9.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 53,
    name: :tf_detoxify,
    display_name: "Detoxify",
    max_level: 1,
    target_type: :target_ally,
    range: 9,
    sp_cost: [10]

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @statuses_to_remove [:sc_poison, :sc_dpoison]

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
          {:ok, PlayerState.t()}
  def cast(caster, target, _level, _definition) do
    {unit_type, target_id} = target_ref(caster, target)

    Enum.each(@statuses_to_remove, fn status ->
      StatusInterpreter.remove_status(unit_type, target_id, status)
    end)

    {:ok, caster}
  end

  defp target_ref(%{character_id: caster_id}, :self), do: {:player, caster_id}
  defp target_ref(_caster, {:unit, {unit_type, unit_id}}), do: {unit_type, unit_id}
  defp target_ref(_caster, {:unit, target_id}), do: {:player, target_id}
end
