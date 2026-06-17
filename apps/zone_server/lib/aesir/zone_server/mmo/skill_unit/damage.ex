defmodule Aesir.ZoneServer.Mmo.SkillUnit.Damage do
  @moduledoc """
  Interim damage hook for ground skill-units.

  The engine has no magic-combat path yet (`DamageCalculator` is entirely
  physical: ATK/weapon/crit/defense). Storm Gust and future magic ground skills
  route their per-hit damage through `magic_stub/4`, the single, clearly-marked
  swap point for the future magic-combat spec. When that lands, this one function
  is replaced by the real `DamageCalculator` magic path and nothing else changes.
  """

  @typedoc "Element atom for the magic hit (e.g. `:water` for Storm Gust)."
  @type element :: atom()

  @doc """
  Returns the interim magic damage a `caster` deals to a `target` at `level`.

  Level-scaled placeholder only — no MATK/MDEF and no element modifier.

  ## Parameters
    - `caster` / `target` - combatant-like structs (unused by the placeholder)
    - `level` - the skill level
    - `element` - the magic element (unused by the placeholder)
  """
  # TODO: replace with real magic damage (MATK/MDEF/element) — see deferred spec
  @spec magic_stub(term(), term(), pos_integer(), element()) :: non_neg_integer()
  def magic_stub(_caster, _target, level, _element), do: 100 + 50 * level
end
