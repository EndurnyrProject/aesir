defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnAutocounter do
  @moduledoc """
  Auto Counter (KN_AUTOCOUNTER). Enemy-targeted self-buff applying
  SC_AUTOCOUNTER to the caster for `400 * level` ms.

  While the buff is active, the next basic melee weapon attack that lands from
  the caster's front or side arc, within their own weapon range, is intercepted:
  the incoming swing deals nothing and the caster answers with a guaranteed
  critical weapon strike. The interception and the counter live entirely in
  SC_AUTOCOUNTER (`status_effect/effects/auto_counter.ex`); casting the skill
  only arms the buff. The counter level is carried in the buff's `val1` so the
  interception can scale its counter ratio.

  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 61,
    name: :kn_autocounter,
    requires: [],
    status: :sc_auto_counter,
    display_name: "Auto Counter",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: -1,
    sp_cost: [3, 3, 3, 3, 3]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @counter_ms_per_level 400

  @impl Active
  def cast(caster, {:unit, _target_id}, level, _definition) do
    adapter = Caster.for(caster)
    caster_id = adapter.id(caster)

    params = [
      val1: level,
      caster_id: caster_id,
      duration: @counter_ms_per_level * level
    ]

    with :ok <-
           StatusInterpreter.apply_status(
             adapter.unit_type(caster),
             caster_id,
             :sc_auto_counter,
             params
           ) do
      {:ok, caster}
    end
  end
end
