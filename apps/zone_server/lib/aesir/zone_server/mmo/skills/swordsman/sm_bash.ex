defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmBash do
  @moduledoc """
  Bash (SM_BASH). Single-target physical strike on an enemy.

  Renewal: a melee-range weapon strike for 100% + 30% per level of weapon
  damage, never a critical, carrying the equipped weapon's own attack element
  (the skill declares no element of its own, so the combat layer keeps the
  weapon element or whatever endow currently overrides it). Every weapon class
  except the bow may cast it. On a confirmed hit it applies the skill riders
  contributed by learned passives - Fatal Blow's stun above Bash level 5.

  Pre-renewal: identical ratio, element, weapon restriction and rider wiring.
  Only the length of the Fatal Blow stun differs, and that constant lives with
  the Fatal Blow passive.

  In both modes the strike is also more likely to connect than an ordinary
  attack: the roll's already-clamped hit rate is raised by 5% per level,
  relative, not by a flat addition to the accuracy stat.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 5,
    name: :sm_bash,
    requires: [],
    display_name: "Bash",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    sp_cost: [8, 8, 8, 8, 8, 15, 15, 15, 15, 15],
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

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100 + 30 * level,
      hit_rate_bonus_pct: 5 * level,
      skip_crit: true,
      report_hit: true
    ]

    case Combat.execute_skill_attack(caster, target, opts) do
      {:ok, %{hit?: true}} ->
        apply_riders(caster, target, level)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp apply_riders(%{character_id: _} = caster, target, level) do
    :sm_bash
    |> Passives.rider_for(level, caster)
    |> Enum.each(fn {:apply_status, status_id, opts} ->
      maybe_apply_rider(caster, target, status_id, opts)
    end)
  end

  defp apply_riders(_caster, _target, _level), do: :ok

  defp maybe_apply_rider(%{character_id: caster_id}, target, status_id, opts) do
    chance = Keyword.fetch!(opts, :chance)

    if :rand.uniform(10_000) <= chance do
      {unit_type, unit_id} = target_ref(target)

      StatusInterpreter.apply_status(unit_type, unit_id, status_id,
        duration: opts[:duration],
        caster_id: caster_id,
        source_type: :player
      )
    end

    :ok
  end

  defp target_ref({unit_type, unit_id}), do: {unit_type, unit_id}

  defp target_ref(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id),
      do: {:mob, target_id},
      else: {:player, target_id}
  end
end
