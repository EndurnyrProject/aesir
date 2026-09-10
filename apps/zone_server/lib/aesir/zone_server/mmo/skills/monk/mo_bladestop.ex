defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoBladestop do
  @moduledoc """
  Root (MO_BLADESTOP), a self-cast that arms the single-use `sc_bladestop_wait`
  ready stance carrying the Monk's Root level; the next eligible melee swing
  against the Monk is caught and establishes the paired Root.

  Renewal: a 0.5 s delay and a 3 s cooldown; the hold lasts 10 s (2 s on a boss).
  Pre-renewal: no delay or cooldown; bosses cannot be caught and the hold lasts
  10 s plus 10 s per level.
  """
  @profile Aesir.ZoneServer.Mmo.Skills.Monk.Formulas.root_profile()

  use Aesir.ZoneServer.Mmo.Skill,
    id: 269,
    name: :mo_bladestop,
    status: :sc_bladestop_wait,
    display_name: "Root",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: List.duplicate(@profile.sp_cost, 5),
    sphere_cost: List.duplicate(@profile.sphere_cost, 5),
    after_cast_delay: [renewal: List.duplicate(@profile.after_cast_delay, 5), pre_renewal: []],
    cooldown: [renewal: List.duplicate(@profile.cooldown, 5), pre_renewal: []],
    duration: [500, 700, 900, 1_100, 1_300]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    params = [
      val1: level,
      caster_id: caster_id,
      duration: Enum.at(definition.duration, level - 1)
    ]

    with :ok <- StatusInterpreter.apply_status(:player, caster_id, :sc_bladestop_wait, params) do
      {:ok, caster}
    end
  end
end
