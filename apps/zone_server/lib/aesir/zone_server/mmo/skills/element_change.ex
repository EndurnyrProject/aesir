defmodule Aesir.ZoneServer.Mmo.Skills.ElementChange do
  @moduledoc """
  The cast body shared by the four `SA_ELEMENT*` converter skills.

  `elementalchangewater.cpp:14-25` is one function reused verbatim by the earth,
  fire and wind variants, the element being the only difference; each skill
  module carries its own metadata and delegates the body here.

  The gate is `if (sd && (!dstmd || status_has_mode(tstatus, MD_STATUSIMMUNE)))
  return;` - a player-cast lands only on a monster that is not status immune.
  Aesir's mob importer maps rAthena's `Class: Boss` to the `:boss` mode but does
  not union in the `MD_STATUSIMMUNE` bit that `mob.cpp:5543` adds for that
  class, and no mob in `priv/db/mobs/mobs.yml` carries `:status_immune`, so
  `MobState.is_boss?/1` is the faithful stand-in for the reference's check.

  A blocked cast still returns `{:ok, caster}`: the reference's early return does
  not set `SKILL_NOCONSUME_REQ`, so the converter is consumed either way.
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

  `val1` is the element level and `val2` the rAthena element id, mirroring
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
