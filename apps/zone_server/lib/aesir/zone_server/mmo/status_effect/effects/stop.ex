defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Stop do
  @moduledoc """
  Stop (SC_STOP).

  A transient movement lock that leaves attacks and skills available.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stop,
    no_dispel: false,
    no_save: true,
    remove_on_map_change: true,
    properties: [:debuff, :prevents_movement],
    flags: [:no_move],
    icon: :stop
end
