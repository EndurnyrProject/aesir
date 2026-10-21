defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnAutocounter do
  @moduledoc """
  Auto Counter (KN_AUTOCOUNTER). Enemy-targeted self-buff applying
  SC_AUTOCOUNTER to the caster for `400 * level` ms.

  While the buff is active, the next basic melee weapon attack that lands from
  the caster's front or side arc, within their own weapon range, is intercepted:
  the incoming swing deals nothing and the caster answers with a guaranteed
  critical weapon strike. The interception and the counter live entirely in
  SC_AUTOCOUNTER (`status_effect/effects/auto_counter.ex`); casting the skill
  only arms the buff; the stance's skill visual reaches onlookers 100 ms later,
  as the reference's delayed timer sends it, and a caster dead by then shows
  nothing. The counter level is carried in the buff's `val1` so the interception
  can scale its counter ratio.

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
    damage_type: :damage,
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

  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast

  @behaviour Active

  @skill_id 61
  @counter_ms_per_level 400
  @effect_delay_ms 100

  @impl Active
  def cast(caster, {:unit, _target_id}, level, definition),
    do: cast(caster, :self, level, definition)

  def cast(caster, :self, level, _definition) do
    adapter = Caster.for(caster)
    caster_id = adapter.id(caster)
    {map_name, _x, _y} = adapter.position(caster)

    params = [
      val1: level,
      caster_id: caster_id,
      duration: @counter_ms_per_level * level
    ]

    StatusInterpreter.apply_status(
      adapter.unit_type(caster),
      caster_id,
      :sc_auto_counter,
      params
    )

    _timer = Skill.defer(__MODULE__, {level, map_name}, @effect_delay_ms)

    {:ok, caster}
  end

  @doc """
  Shows the armed stance to onlookers a moment after the cast, as the
  reference's delayed timer does. A caster that died or changed map since the
  cast shows nothing, since that timer is cleared with the unit's map.
  """
  @impl Active
  def deferred({level, cast_map_name}, caster) do
    adapter = Caster.for(caster)
    {map_name, x, y} = adapter.position(caster)

    if Unit.living?(caster) and map_name == cast_map_name do
      unit_id = adapter.id(caster)

      Broadcast.to_in_range(map_name, x, y, Config.view_range(), %SkillEffect{
        skill_id: @skill_id,
        level: level,
        target_id: unit_id,
        src_id: unit_id,
        result: 1
      })
    end

    :ok
  end
end
