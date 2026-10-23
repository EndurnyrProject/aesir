defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrSlowpoison do
  @moduledoc """
  Slow Poison (PR_SLOWPOISON). Suspends Poison and Deadly Poison damage ticks on an
  ally for 10 s per level.

  Renewal and pre-renewal agree: 9-cell range and 6 to 12 SP.
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

    StatusInterpreter.apply_status(unit_type, target_id, :sc_slowpoison,
      caster_id: caster_id,
      duration: duration
    )

    {:ok, caster}
  end
end
