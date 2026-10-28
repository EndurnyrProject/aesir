defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Magnificat do
  @moduledoc """
  Magnificat (SC_MAGNIFICAT).

  Doubles the natural SP regeneration tick rate.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_magnificat,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:regen],
    end_on_start: [:sc_offertorium],
    prevented_by: [:sc_refresh, :sc_inspiration],
    no_save: true,
    icon: :magnificat

  @impl true
  def modifiers(_instance, _context), do: %{sp_regen_tick_rate: 100}
end
