defmodule Aesir.ZoneServer.Mmo.Skills.AlCure do
  @moduledoc """
  Cure (AL_CURE). Removes Silence, Blind, and Confusion from an ally.

  rAthena: id 35, max level 1, SP 15, AfterCastActDelay 1000ms.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 35,
    name: :al_cure,
    display_name: "Cure",
    max_level: 1,
    target_type: :target_ally,
    range: 9,
    sp_cost: [15],
    after_cast_delay: [1_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @statuses_to_remove [:sc_silence, :sc_blind, :sc_confusion]

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, target, _level, _definition) do
    target_id = resolve_target_id(caster, target)

    Enum.each(@statuses_to_remove, fn status ->
      StatusInterpreter.remove_status(:player, target_id, status)
    end)

    {:ok, caster}
  end

  defp resolve_target_id(%{character_id: caster_id}, :self), do: caster_id
  defp resolve_target_id(_caster, {:unit, id}), do: id
end
