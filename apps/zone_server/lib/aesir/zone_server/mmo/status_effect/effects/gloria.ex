defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Gloria do
  @moduledoc """
  Gloria (SC_GLORIA).

  Grants +30 LUK.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_gloria,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:luk],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :gloria

  @impl true
  def modifiers(_instance, _context), do: %{luk: 30}
end
