defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsMadnesscancel do
  @moduledoc """
  Madness Canceller (GS_MADNESSCANCEL) starts SC_MADNESSCANCEL for 15 s.
  Casting it while the status is held ends the status instead and still spends
  30 SP and the coins. Renewal: 1 coin, 1600 ms cast plus 400 ms fixed, 3 s
  delay. Pre-renewal: 4 coins, 3000 ms cast, 4 s delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 504,
    name: :gs_madnesscancel,
    requires: [],
    display_name: "Madness Canceller",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :weapon,
    status: :sc_madnesscancel,
    sp_cost: [30],
    sphere_cost: [renewal: [1], pre_renewal: [4]],
    cast_time: [renewal: [1600], pre_renewal: [3000]],
    fixed_cast_time: [renewal: [400], pre_renewal: []],
    after_cast_delay: [renewal: [3000], pre_renewal: [4000]],
    duration: [15_000]

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
    StatusInterpreter.apply_status(:player, caster_id, :sc_madnesscancel, params)
    {:ok, caster}
  end
end
