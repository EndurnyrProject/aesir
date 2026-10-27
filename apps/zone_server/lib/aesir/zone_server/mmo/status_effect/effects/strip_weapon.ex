defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StripWeapon do
  @moduledoc """
  Divest Weapon (SC_STRIPWEAPON).

  A player loses the weapon slot; a stripped monster or homunculus keeps its
  attack but loses 25 percent of its ATK percent.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stripweapon,
    immunity: [:boss],
    metadata: %{strip_slot: :right_hand},
    no_dispel: true,
    no_save: true,
    no_clear_buff: false,
    clear_buff_flags: [:debuff, :remove_on_hermode],
    properties: [:debuff],
    bypass_resistance: true,
    icon: :noequipweapon

  @impl true
  def modifiers(_instance, %{unit_type: :player}), do: %{}
  def modifiers(_instance, _context), do: %{atk_rate: -25}
end
