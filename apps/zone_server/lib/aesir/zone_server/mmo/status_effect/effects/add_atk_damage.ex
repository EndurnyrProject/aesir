defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AddAtkDamage do
  @moduledoc """
  Added physical-damage buff (SC_ADD_ATK_DAMAGE).

  Adds `val1` percent to physical damage (attacker-side, `battle.cpp:2003-2004`;
  `db/re/status.yml` `bonus bAtkRate`). Modelled with the same `atk_rate` percent
  delta the combat calculator consumes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_add_atk_damage,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:atk_rate],
    icon: :add_atk_damage

  @impl true
  def modifiers(instance, _context), do: %{atk_rate: instance.val1}
end
