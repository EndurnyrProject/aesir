defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsIncreasing do
  @moduledoc """
  Increasing Accuracy (GS_INCREASING) starts SC_INCREASING for 60 s; recasting
  refreshes it. 30 SP and 4 coins, no cast time, 1 s delay in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 506,
    name: :gs_increasing,
    requires: [],
    display_name: "Increasing Accuracy",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :weapon,
    status: :sc_increasing,
    sp_cost: [30],
    sphere_cost: [4],
    after_cast_delay: [1000],
    duration: [60_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    params = [val1: level, caster_id: caster_id, duration: hd(definition.duration)]
    StatusInterpreter.apply_status(:player, caster_id, :sc_increasing, params)
    {:ok, caster}
  end
end
