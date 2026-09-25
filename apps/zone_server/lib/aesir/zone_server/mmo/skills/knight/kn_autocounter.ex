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

  Renewal and pre-renewal agree: the stance accepts unarmed combat and the
  enumerated melee/ranged weapon types (not bows), lasts 0.4 s per level, and
  turns the next front or side melee swing into a guaranteed critical counter
  at 100% plus 10% per level.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 61,
    name: :kn_autocounter,
    requires: [],
    status: :sc_auto_counter,
    display_name: "Auto Counter",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    range: 0,
    sp_cost: [3, 3, 3, 3, 3],
    require_weapon: [
      :book,
      :dagger,
      :fist,
      :gatling,
      :grenade,
      :huuma,
      :katar,
      :knuckle,
      :mace,
      :musical,
      :one_handed_axe,
      :one_handed_spear,
      :one_handed_sword,
      :revolver,
      :rifle,
      :shotgun,
      :staff,
      :two_handed_axe,
      :two_handed_mace,
      :two_handed_spear,
      :two_handed_sword,
      :whip
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @counter_ms_per_level 400

  @impl Active
  def cast(caster, {:unit, _target_id}, level, definition),
    do: cast(caster, :self, level, definition)

  def cast(caster, :self, level, _definition) do
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
