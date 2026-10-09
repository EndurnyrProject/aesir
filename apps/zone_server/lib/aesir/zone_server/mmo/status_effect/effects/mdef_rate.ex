defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MdefRate do
  @moduledoc """
  Magic damage-taken reduction buff (SC_MDEF_RATE).

  This consumable-family status is **not** an MDEF buff: it scales incoming
  magic damage by `(100 - val1) / 100` as the last factor of the target's magic
  card fix. It is therefore emitted as `magic_damage_reduction`, not as
  `mdef`/`mdef_rate`. val1-driven.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_mdef_rate,
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    calc_flags: [:magic_damage_reduction],
    icon: :protect_mdef

  @impl true
  def modifiers(instance, _context), do: %{magic_damage_reduction: instance.val1}
end
