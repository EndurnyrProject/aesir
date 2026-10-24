defmodule Aesir.ZoneServer.Mmo.Skill.Caster do
  @moduledoc """
  Identity and geometry interface shared by skill casters.
  """

  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Memorize
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Npc.SkillCaster
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @type kind :: :player | :homunculus | :mob | :npc
  @type state :: any()

  @callback kind() :: kind()
  @callback provides() :: [Aesir.ZoneServer.Mmo.Skill.Requirement.t()]
  @callback id(state()) :: integer()
  @callback unit_type(state()) :: Aesir.ZoneServer.Unit.unit_type()
  @callback position(state()) :: {String.t(), integer(), integer()}
  @callback attack_range(state()) :: non_neg_integer()
  @callback broadcast_source(state()) ::
              integer() | {Aesir.ZoneServer.Unit.unit_type(), integer()}
  @callback sp(state()) :: non_neg_integer()
  @callback deduct_sp(state(), non_neg_integer()) :: state()

  @doc """
  Runs the caster's cast-start effects (statuses reacting to the start of a
  skill cast) for a cast resolving instantly, before its effect. Optional.
  """
  @callback on_cast_start(state(), integer()) :: state()

  @doc """
  Settles the caster's own state after a skill effect that executed a skill
  attack, given the caster state the effect started from. Optional; a caster
  with nothing to settle omits it.
  """
  @callback on_skill_attack(state(), state()) :: state()

  @optional_callbacks on_cast_start: 2, on_skill_attack: 2

  @doc "Applies the returned cast-time reactions to the caster's own statuses once."
  @spec apply_cast_reactions(state(), [CastTime.reaction()]) :: state()
  def apply_cast_reactions(caster, []), do: caster

  def apply_cast_reactions(caster, reactions) do
    adapter = __MODULE__.for(caster)
    type = adapter.unit_type(caster)
    id = adapter.id(caster)

    Enum.each(reactions, fn
      :consume_memorize -> Memorize.consume_charge(type, id)
      :end_suffragium -> StatusInterpreter.remove_status(type, id, :sc_suffragium)
    end)

    case caster do
      %PlayerState{} -> __MODULE__.Player.refresh_after_cast_reactions(caster)
      _other -> caster
    end
  end

  @spec for(struct()) :: module()
  def for(%PlayerState{}), do: __MODULE__.Player
  def for(%HomunculusState{}), do: __MODULE__.Homunculus
  def for(%MobState{}), do: __MODULE__.Mob
  def for(%SkillCaster{}), do: SkillCaster

  def for(%module{}) do
    raise ArgumentError, "unsupported skill caster struct: #{inspect(module)}"
  end

  @spec for_kind(kind()) :: module()
  def for_kind(:player), do: __MODULE__.Player
  def for_kind(:homunculus), do: __MODULE__.Homunculus
  def for_kind(:mob), do: __MODULE__.Mob
  def for_kind(:npc), do: SkillCaster

  def for_kind(other) do
    raise ArgumentError, "unsupported caster kind: #{inspect(other)}"
  end
end
