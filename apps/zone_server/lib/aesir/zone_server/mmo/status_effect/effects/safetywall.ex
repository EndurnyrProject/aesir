defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Safetywall do
  @moduledoc """
  Safety Wall (SC_SAFETYWALL).

  A marker granted to whoever stands on a Safety Wall ground unit. While active it
  fully blocks short-range physical hits via the pre-damage `absorb_damage` hook;
  magic and ranged hits pass through unchanged.

  The hit/shield budget is **shared by the wall**, not the defender: it lives on
  the owning ground unit's `state` (`hits_remaining = level + 1`,
  `shield_hp = 300*level + 65*(INT + baseLv) + maxSP` from the caster's stats) and
  is set when the wall is placed (see `MgSafetywall`). The skill-unit manager
  atomically reads and spends both budgets for each blocked hit. When either runs
  out, the final hit stays blocked while the wall and marker are removed; a hit
  landing after the wall is already gone passes through and ends the stale marker.

  The status only keeps the wall's `group_id` in its own state, for the
  unit<->status linkage.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_safetywall,
    no_dispel: true,
    properties: [:buff],
    no_save: true

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.ZoneServer.Mmo.Skill.Unit

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
      )
      when damage > 0 do
    group_id = instance.state.group_id

    case Unit.absorb_safetywall_hit(group_id, damage) do
      {:block, :remove} ->
        {:remove, 0}

      {:block, :keep} ->
        {:ok, 0, instance}

      :pass ->
        :remove
    end
  end

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}
end
