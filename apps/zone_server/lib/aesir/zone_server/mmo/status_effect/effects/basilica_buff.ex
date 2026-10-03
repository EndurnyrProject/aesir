defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BasilicaBuff do
  @moduledoc """
  Renewal Basilica (SC_BASILICA in renewal). `val1` is the skill level.

  The caster's weapon attacks deal `5 * level` percent more damage to Dark and
  Undead element targets, summed with equipment element bonuses, and Holy
  element spells gain `3 * level` percent. It restricts nothing.

  Pre-renewal Basilica is a different mechanic (a sanctuary field) carried by
  `sc_basilica` and `sc_basilica_caster`; this status is renewal-only.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_basilica_buff,
    no_save: true,
    no_dispel: false,
    properties: [:buff],
    icon: :basilica_buff

  @impl true
  def modifiers(%{val1: level}, _context) do
    %{
      {:addele, :dark} => 5 * level,
      {:addele, :undead} => 5 * level,
      {:magic_atk_ele, :holy} => 3 * level
    }
  end
end
