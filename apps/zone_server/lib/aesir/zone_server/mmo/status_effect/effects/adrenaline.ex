defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adrenaline do
  @moduledoc """
  Adrenaline Rush (SC_ADRENALINE).

  Grants a flat `+7` ASPD at every level — the bonus does not scale — plus HIT
  that does, carried as `5 + 3 * val1` (8 through 20 across levels 1-5). Ends
  the moment its holder wields anything other than a one- or two-handed axe or
  a mace.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_adrenaline,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:aspd, :hit],
    require_weapon: [:one_handed_axe, :two_handed_axe, :mace],
    icon: :adrenaline

  @impl true
  def modifiers(instance, _context), do: %{aspd: 7, hit: 5 + 3 * instance.val1}
end
