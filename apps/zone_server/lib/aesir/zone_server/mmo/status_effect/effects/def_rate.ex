defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DefRate do
  @moduledoc """
  Physical damage-taken reduction buff (SC_DEF_RATE).

  This consumable-family status is **not** a DEF buff: it scales incoming weapon
  damage by `(100 - val1) / 100` as the last of the target's card families
  (after the long-range defense family), per renewal component or on the
  finished classic and non-player hit. It is therefore emitted as
  `phys_damage_reduction`, not as `def`/`def_rate`. val1-driven.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_def_rate,
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    calc_flags: [:phys_damage_reduction],
    icon: :protect_def

  @impl true
  def modifiers(instance, _context), do: %{phys_damage_reduction: instance.val1}
end
