defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MdefRate do
  @moduledoc """
  Magic damage-taken reduction buff (SC_MDEF_RATE).

  This consumable-family status is **not** an MDEF buff: rAthena multiplies
  incoming magic damage on the target by `(100 - val1) / 100`
  (`battle.cpp:932-933`). It is therefore modelled as `magic_damage_reduction`
  (percent of final magic damage the defender shrugs off), consumed in
  `combat/magic_damage_calculator.ex`, not as `mdef`/`mdef_rate`. val1-driven.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_mdef_rate,
    properties: [:buff],
    calc_flags: [:magic_damage_reduction],
    icon: :protect_mdef

  @impl true
  def modifiers(instance, _context), do: %{magic_damage_reduction: instance.val1}
end
