defmodule Aesir.ZoneServer.Mmo.Skills.Sage.ElementChange do
  @moduledoc """
  Shared behaviour of the four Elemental Change quest skills: the target monster's
  defence element becomes the skill's element for the status duration.

  Renewal and pre-renewal agree on the effect; only the cast type differs per
  skill.
  """
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Overrides the target monster's defense element with the skill's own element.

  `val1` is the element level and `val2` the source element id, mirroring
  `sc_start2(src, target, type, 100, skill_lv, skill_get_ele(...))`. The
  reference's `src` is not carried because `sc_elementalchange` reads no
  caster context.
  """
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(caster, {:unit, target_id}, level, definition) do
    if overridable_mob?(target_id) do
      StatusInterpreter.apply_status(:mob, target_id, definition.status,
        val1: level,
        val2: ElementModifiers.id(definition.element),
        duration: Enum.at(definition.duration, level - 1)
      )
    end

    {:ok, caster}
  end

  @spec overridable_mob?(integer()) :: boolean()
  defp overridable_mob?(target_id) do
    case UnitRegistry.get_unit(:mob, target_id) do
      {:ok, {MobState, mob_state, _pid}} -> not MobState.is_boss?(mob_state)
      {:error, :not_found} -> false
    end
  end
end
