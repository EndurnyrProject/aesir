defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnchantPoison do
  @moduledoc """
  Enchant Poison (SC_ENCPOISON).

  Endows the weapon with the poison element, replacing other weapon endows.
  The chance to poison targets on attack awaits attack-event dispatch in the
  combat engine.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_encpoison,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:atk_ele],
    end_on_start: [
      :sc_aspersio,
      :sc_fireweapon,
      :sc_waterweapon,
      :sc_windweapon,
      :sc_earthweapon,
      :sc_shadowweapon,
      :sc_ghostweapon,
      :sc_watk_element
    ],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :enchantpoison

  @impl true
  def modifiers(_instance, _context), do: %{attack_element: :poison}
end
