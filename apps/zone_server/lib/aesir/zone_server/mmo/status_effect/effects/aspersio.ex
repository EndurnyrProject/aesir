defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Aspersio do
  @moduledoc """
  Aspersio (SC_ASPERSIO).

  Endows the weapon with the holy element, replacing other weapon endows.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_aspersio,
    properties: [:buff],
    calc_flags: [:atk_ele],
    end_on_start: [
      :sc_encpoison,
      :sc_fireweapon,
      :sc_waterweapon,
      :sc_windweapon,
      :sc_earthweapon,
      :sc_shadowweapon,
      :sc_ghostweapon,
      :sc_watk_element
    ],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :aspersio

  @impl true
  def modifiers(_instance, _context), do: %{attack_element: :holy}
end
