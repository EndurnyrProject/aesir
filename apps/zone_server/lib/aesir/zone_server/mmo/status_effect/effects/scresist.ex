defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Scresist do
  @moduledoc """
  Status resistance (SC_SCRESIST).

  Subtracts `val1` percent from the success rate of every debuff applied to the
  holder; at 100 the holder is immune to debuffs for the duration. Buffs are
  unaffected. Granted by Gospel's "immunity to all status" blessing and by item
  scripts; identical in both game modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_scresist,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:ailment_resist_rate]

  @impl true
  def modifiers(instance, _context), do: %{ailment_resist_rate: instance.val1}
end
