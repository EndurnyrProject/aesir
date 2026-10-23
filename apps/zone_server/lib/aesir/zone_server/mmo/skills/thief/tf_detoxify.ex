defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfDetoxify do
  @moduledoc """
  Detoxify (TF_DETOXIFY). Removes Poison and Deadly Poison from an ally.

  id 53, max level 1, SP 10, range 9.

  Renewal and pre-renewal agree: ends Poison and Deadly Poison on the target for 10 SP.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 53,
    name: :tf_detoxify,
    display_name: "Detoxify",
    max_level: 1,
    target_type: :target_ally,
    element: :poison,
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

  @doc "A player may support only their own Homunculus; any other is refused silently."
  @impl Active
  @spec skilluse_check(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :target_restricted}
  def skilluse_check(caster, target, _level, _definition), do: homunculus_support(caster, target)

  @doc """
  Checks the Homunculus ownership again when the cast ends; a caster that is
  not a player may not support a Homunculus at all.
  """
  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :target_restricted}
  def validate(caster, target, _level, _definition), do: homunculus_support(caster, target)

  defp homunculus_support(%{character_id: caster_id}, {:unit, {:homunculus, gid}}) do
    with {:ok, caster_combatant} <- TargetResolver.resolve_combatant(:player, caster_id),
         {:ok, target_combatant} <- TargetResolver.resolve_combatant(:homunculus, gid),
         true <- Targeting.direct_support?(caster_combatant, target_combatant) do
      :ok
    else
      _ -> {:error, :target_restricted}
    end
  end

  defp homunculus_support(_caster, {:unit, {:homunculus, _gid}}), do: {:error, :target_restricted}
  defp homunculus_support(_caster, _target), do: :ok

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

  defp target_ref(caster, target), do: Active.target_unit_ref(caster, target)
end
