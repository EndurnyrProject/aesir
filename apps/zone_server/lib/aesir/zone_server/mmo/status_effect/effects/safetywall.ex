defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Safetywall do
  @moduledoc """
  Safety Wall (SC_SAFETYWALL).

  A marker granted to whoever stands on a Safety Wall ground unit. While active it
  fully blocks short-range physical hits via the pre-damage `absorb_damage` hook;
  magic and ranged hits pass through unchanged.

  The hit/shield budget is **shared by the wall**, not the defender: it lives on
  the owning ground unit's `state` (`hits_remaining = level + 1`,
  `shield_hp = 300*level + 65*(INT + baseLv) + maxSP` from the caster's stats) and
  is set when the wall is placed (see `MgSafetywall`). Each blocked hit decrements
  that shared budget through `Skill.Unit.update_state/2`. When it runs out the wall
  is torn down via `Skill.Unit.destroy/1` (rAthena `skill_delunitgroup`) and the
  status ends; a hit landing after the wall is already gone simply ends the status.

  The status only keeps the wall's `group_id` in its own state, for the
  unit<->status linkage.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_safetywall,
    properties: [:buff],
    no_save: true

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  @impl true
  def on_apply(_target, %{val2: group_id} = instance, _context) do
    {:ok, put_state(instance, group_id: group_id)}
  end

  @impl true
  def absorb_damage(
        _target,
        instance,
        %{damage: damage, is_short: true, dmg_type: :physical},
        _context
      ) do
    group_id = instance.state.group_id

    case Unit.fetch(group_id) do
      {:ok, %Group{state: %{hits_remaining: hits, shield_hp: shield_hp}}}
      when hits - 1 <= 0 or shield_hp - damage <= 0 ->
        Unit.destroy(group_id)
        :remove

      {:ok, %Group{state: %{hits_remaining: hits, shield_hp: shield_hp}}} ->
        Unit.update_state(group_id, %{hits_remaining: hits - 1, shield_hp: shield_hp - damage})
        {:ok, 0, instance}

      :error ->
        :remove
    end
  end

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}
end
