defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adrenaline2 do
  @moduledoc """
  Advanced Adrenaline Rush (SC_ADRENALINE2).

  Grants a flat `+6` ASPD. Ends the moment its holder wields a weapon outside
  the supported list — melee weapons, instruments, whips and books are allowed;
  bows, firearms, huuma shuriken and two-handed staves are not.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_adrenaline2,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:aspd],
    require_weapon: [
      :fist,
      :dagger,
      :one_handed_sword,
      :two_handed_sword,
      :one_handed_spear,
      :two_handed_spear,
      :one_handed_axe,
      :two_handed_axe,
      :mace,
      :two_handed_mace,
      :staff,
      :knuckle,
      :musical,
      :whip,
      :book,
      :katar
    ],
    icon: :adrenaline2

  @impl true
  def modifiers(_instance, _context), do: %{aspd: 6}
end
