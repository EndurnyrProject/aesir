defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Loud do
  @moduledoc """
  Crazy Uproar (SC_LOUD). Renewal: +4 STR, +30 base ATK.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_loud,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:str, :watk]

  @impl true
  def modifiers(_instance, _context), do: %{str: 4, watk: 30}
end
