defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsAdjustment do
  @moduledoc """
  Adjustment (GS_ADJUSTMENT) starts SC_ADJUSTMENT for 30 s; recasting refreshes
  it. 15 SP and 2 coins. Renewal: 800 ms cast plus 200 ms fixed, 2 s delay.
  Pre-renewal: 1000 ms cast, 1 s delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 505,
    name: :gs_adjustment,
    requires: [],
    display_name: "Adjustment",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :weapon,
    status: :sc_adjustment,
    sp_cost: [15],
    sphere_cost: [2],
    cast_time: [renewal: [800], pre_renewal: [1000]],
    fixed_cast_time: [renewal: [200], pre_renewal: []],
    after_cast_delay: [renewal: [2000], pre_renewal: [1000]],
    duration: [30_000]

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
    StatusInterpreter.apply_status(:player, caster_id, :sc_adjustment, params)
    {:ok, caster}
  end
end
