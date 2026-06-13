defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Gloria do
  @moduledoc """
  Gloria (SC_GLORIA).

  Grants +30 LUK.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_gloria,
    properties: [:buff],
    calc_flags: [:luk],
    prevented_by: [:sc_refresh, :sc_inspiration]

  @impl true
  def modifiers(_instance, _context), do: %{luk: 30}
end
