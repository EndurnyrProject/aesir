defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DefRate do
  @moduledoc """
  Physical damage-taken reduction buff (SC_DEF_RATE).

  This consumable-family status is **not** a DEF buff: rAthena multiplies
  incoming weapon damage on the target by `(100 - val1) / 100`
  (`battle.cpp:1151-1152`). It is therefore modelled as `phys_damage_reduction`
  (percent of final physical damage the defender shrugs off), consumed in
  `combat/damage_calculator.ex`, not as `def`/`def_rate`. val1-driven.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_def_rate,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:phys_damage_reduction],
    icon: :protect_def

  @impl true
  def modifiers(instance, _context), do: %{phys_damage_reduction: instance.val1}
end
