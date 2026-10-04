defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfDoublecasting do
  @moduledoc """
  Double Casting (PF_DOUBLECASTING). For 90 s, each bolt the Professor lands has
  a `30 + 10 * level` percent chance to be cast once more, one attack motion
  later and for free (`:sc_doublecast`).

  Both modes: 40 to 60 SP. Renewal: 1.6 s cast plus 0.4 s fixed. Pre-renewal:
  2 s cast.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 482,
    name: :pf_doublecasting,
    status: :sc_doublecast,
    display_name: "Double Casting",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    sp_cost: [40, 45, 50, 55, 60],
    cast_time: [renewal: List.duplicate(1_600, 5), pre_renewal: List.duplicate(2_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(400, 5), pre_renewal: []],
    duration: List.duplicate(90_000, 5)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{character_id: id} = caster, :self, level, definition) do
    with :ok <-
           StatusInterpreter.apply_status(:player, id, :sc_doublecast,
             val1: level,
             caster_id: id,
             duration: Enum.at(definition.duration, level - 1)
           ) do
      {:ok, caster}
    end
  end
end
