defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaSacrifice do
  @moduledoc """
  Martyr's Reckoning (PA_SACRIFICE). Self-casts SC_SACRIFICE for 100 SP: the
  caster's next five ordinary swings become max-HP strikes that ignore DEF and
  FLEE and cost 9% max HP each (see `StatusEffect.Effects.Sacrifice`). The
  status has no timer; it ends when the fifth swing is spent.

  Renewal: no after-cast delay. Pre-renewal: a 2 s after-cast delay. The
  strike formula is shared. Player-only: the mechanic converts the holder's
  basic attacks, which mobs do not route through the replacement seam.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 368,
    name: :pa_sacrifice,
    requires: [],
    status: :sc_sacrifice,
    display_name: "Martyr's Reckoning",
    max_level: 5,
    target_type: :self,
    sp_cost: List.duplicate(100, 5),
    after_cast_delay: [renewal: List.duplicate(0, 5), pre_renewal: List.duplicate(2_000, 5)]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(%PlayerState{character_id: id} = caster, _target, level, _definition) do
    case StatusInterpreter.apply_status(:player, id, :sc_sacrifice, val1: level, caster_id: id) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  def cast(%MobState{}, _target, _level, _definition), do: {:error, :player_only}
end
