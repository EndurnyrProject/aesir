defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WinkCharm do
  @moduledoc """
  Wink of Charm (SC_WINKCHARM).

  Prevents a monster from targeting the Dancer who charmed it. Active damage
  breaks it; a non-player holder keeps it while the damage takes no HP, a player
  does not. Passive HP costs and ticks never break it.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_winkcharm,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:debuff],
    properties: [:debuff],
    flags: [:remove_on_damaged],
    icon: :dc_winkcharm
end
