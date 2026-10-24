defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Agiup do
  @moduledoc """
  NPC Increase AGI's buff (SC_AGIUP).

  Renewal and pre-renewal agree: the holder moves with a `val1` percent haste
  (the strongest haste wins, like Increase AGI's 25) and its FLEE rises by
  `val2` percent. The skill starts it with `val1` 50 and `val2` 100. Decrease
  AGI ends it; Clear Buff does not.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_agiup,
    no_dispel: false,
    no_clear_buff: true,
    properties: [:buff],
    calc_flags: [:speed, :flee],
    end_on_start: [:sc_decreaseagi],
    icon: :agiup

  @impl true
  def modifiers(instance, _context), do: %{haste_rate: instance.val1, flee_rate: instance.val2}
end
