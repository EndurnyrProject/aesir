defmodule Aesir.ZoneServer.Mmo.Skills.Sage.Endow do
  @moduledoc """
  Shared cast and success roll for the four Sage weapon endows.

  Renewal endows always succeed. Pre-renewal endows succeed 60% plus 10% per level
  of the time; a failure unequips the target's weapon and reports the failure, as
  does a bare-handed target in either mode. A refused status is reported the same
  way in pre-renewal (the roll and the status start are one call there) and is
  silent in renewal.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Applies `status` to the resolved target for the level's duration unless the classic roll fails."
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t(), atom()) ::
          {:ok, PlayerState.t()}
          | {:failed, PlayerState.t(), atom()}
          | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, target, level, definition, status) do
    target_id = Active.resolve_target_id(caster, target)

    cond do
      bare_handed?(caster, target_id) ->
        {:failed, caster, :bare_handed}

      classic_failure?(level) ->
        endow_failure(caster, target_id, :endow_failed)

      true ->
        apply_endow(caster, caster_id, target_id, level, definition, status)
    end
  end

  defp apply_endow(caster, caster_id, target_id, level, definition, status) do
    case StatusInterpreter.apply_status(:player, target_id, status,
           val1: level,
           caster_id: caster_id,
           duration: Enum.at(definition.duration, level - 1)
         ) do
      :ok -> {:ok, caster}
      {:error, reason} -> refused(caster, target_id, reason)
    end
  end

  # Renewal only reports the animation; pre-renewal folds a refused status into
  # the same failure path as a failed roll.
  defp refused(caster, target_id, reason) do
    if GameMode.mode() == :renewal,
      do: {:ok, caster},
      else: endow_failure(caster, target_id, reason)
  end

  defp endow_failure(caster, target_id, reason) do
    unequip_target_weapon(target_id)
    {:failed, caster, reason}
  end

  defp unequip_target_weapon(target_id) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        PlayerSession.unequip_slot(pid, :right_hand)

      _not_online ->
        :ok
    end
  end

  defp bare_handed?(%{character_id: caster_id} = caster, caster_id),
    do: PlayerStats.weapon_type(caster.stats.equipment) == :fist

  defp bare_handed?(_caster, target_id) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, target, _pid}} -> PlayerStats.weapon_type(target.stats.equipment) == :fist
      {:error, :not_found} -> false
    end
  end

  @doc """
  Whether this classic endow cast fails its success roll; never in renewal.
  `roll` draws the percentile (1..100) and defaults to the random generator.
  """
  @spec classic_failure?(pos_integer(), (pos_integer() -> pos_integer())) :: boolean()
  def classic_failure?(level, roll \\ &:rand.uniform/1) do
    GameMode.mode() == :pre_renewal and roll.(100) > 60 + 10 * level
  end
end
