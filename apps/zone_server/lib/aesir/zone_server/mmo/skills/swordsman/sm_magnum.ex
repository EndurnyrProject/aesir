defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmMagnum do
  @moduledoc """
  Magnum Break (SM_MAGNUM). Self-centered splash fire strike.

  Deals fire-element splash damage to every enemy within `splash_radius` of the
  caster's own cell, knocks each hit target back, and leaves the caster wrapped
  in a ten second fire aura.

  The aura is not an endow: in both modes the caster's attacks keep their own
  element and additionally deal 20 percent of themselves as fire damage,
  resolved against the victim's element separately from the main hit.

  Where the two modes differ is which slot holds it. Renewal gives the aura its
  own secondary weapon-property slot, so it coexists with a weapon endow - a
  swordsman under Aspersio who casts Magnum Break keeps both. Classic has no
  such slot and expresses the aura through the shared weapon-element property,
  which replaces any endow that was up and is replaced in turn by the next one
  cast. Both slots feed the damage layer the same partial-element bonus, so the
  20 percent behaves identically once applied.

  Renewal: costs SP only, releases the caster after a short half-second
  aftercast delay, and then holds the skill on a two second cooldown, so the
  pace is set by the cooldown rather than by the caster's own action lock.

  Pre-renewal: no cooldown at all, but the caster is locked for a full two
  seconds after the cast, and the skill additionally demands (without spending)
  a health reserve that shrinks with skill level, from 20 HP at level 1 down to
  16 HP at level 10. A caster at or below that reserve cannot start the cast;
  a caster above it pays nothing but SP. That "required but never spent" health
  gate is enforced in `validate/4` rather than declared as an HP cost, because
  a declared cost would be deducted on every cast.

  In both modes the blast falls off with distance: victims within one cell of
  the caster take 100% + 20% per level, everyone further out 100% + 10% per
  level. Every victim is also 10% per level more likely to be hit, a relative
  bonus on the already-clamped hit rate rather than a flat accuracy addition.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 7,
    name: :sm_magnum,
    requires: [:player_state],
    display_name: "Magnum Break",
    max_level: 10,
    target_type: :self,
    damage_type: :damage,
    element: :fire,
    knockback: 2,
    splash_radius: 2,
    sp_cost: List.duplicate(30, 10),
    after_cast_delay: [
      renewal: List.duplicate(500, 10),
      pre_renewal: List.duplicate(2_000, 10)
    ],
    cooldown: [renewal: List.duplicate(2_000, 10), pre_renewal: List.duplicate(0, 10)],
    duration: List.duplicate(10_000, 10)

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  # Fire, in the element ordering the weapon-property buff carries as val1.
  @fire_element 3

  # Percentage of the caster's own attack the aura additionally deals as fire.
  @fire_aura_percent 20

  @classic_hp_requirement [20, 20, 19, 19, 18, 18, 17, 17, 16, 16]

  @behaviour Active

  @impl Active
  def validate(caster, _target, level, _definition) do
    case GameMode.mode() do
      :renewal -> :ok
      :pre_renewal -> check_health_reserve(caster, level)
    end
  end

  @impl Active
  def cast(%{character_id: caster_id, x: x, y: y} = caster, :self, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: &ring_ratio(&1, level),
      hit_rate_bonus_pct: 10 * level,
      element: definition.element,
      skip_crit: true,
      base_distance: definition.knockback,
      origin: {x, y},
      native_target_types: [:mob]
    ]

    _ = Combat.execute_splash_attack(caster, {x, y}, definition.splash_radius, opts)

    duration = Enum.at(definition.duration, level - 1)

    params = [
      val1: @fire_element,
      val2: @fire_aura_percent,
      caster_id: caster_id,
      duration: duration
    ]

    case StatusInterpreter.apply_status(:player, caster_id, fire_aura_status(), params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp fire_aura_status do
    case GameMode.mode() do
      :renewal -> :sc_sub_weaponproperty
      :pre_renewal -> :sc_watk_element
    end
  end

  # The blast falls off with distance: the three-by-three ring centred on the
  # caster takes 100% + 20% per level, everything further out 100% + 10%.
  defp ring_ratio(distance, level) when distance <= 1, do: 100 + 20 * level
  defp ring_ratio(_distance, level), do: 100 + 10 * level

  defp check_health_reserve(%{stats: %{current_state: %{hp: hp}}}, level) do
    if hp > Enum.at(@classic_hp_requirement, level - 1),
      do: :ok,
      else: {:error, :insufficient_hp}
  end

  # Script- and NPC-driven casters carry no health pool to reserve against.
  defp check_health_reserve(_caster, _level), do: :ok
end
