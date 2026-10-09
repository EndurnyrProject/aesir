defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DoubleCast do
  @moduledoc """
  Double Casting (SC_DOUBLECAST). While it lasts, each Cold Bolt, Fire Bolt or
  Lightning Bolt the holder lands has a `30 + 10 * level` percent chance to be
  cast once more for free (`Skills.Shared.BoltEcho`). Identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_doublecast,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    no_save: true,
    properties: [:buff],
    icon: :doublecasting

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def on_apply(_target, instance, _context),
    do: {:ok, put_state(instance, :chance, 30 + 10 * instance.val1)}
end
