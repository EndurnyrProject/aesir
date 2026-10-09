defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WinkCharm do
  @moduledoc """
  Wink of Charm (SC_WINKCHARM).

  Prevents a monster from targeting the Dancer who charmed it until the
  monster takes active HP damage. In both modes, active zero-damage
  notifications also release players, but passive HP costs and ticks do not.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_winkcharm,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:debuff],
    properties: [:debuff],
    icon: :dc_winkcharm

  @impl true
  def on_damage({:player, _id}, _instance, _damage_info, _context), do: :remove

  def on_damage(_target, _instance, %{damage: damage}, _context) when damage > 0,
    do: :remove

  def on_damage(_target, instance, _damage_info, _context), do: {:ok, instance}
end
