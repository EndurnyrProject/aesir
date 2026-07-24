defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Defender do
  @moduledoc """
  Defender (SC_DEFENDER).

  Persistent toggle that trades attack speed for reduced long-range weapon
  damage taken. No duration; ends when the skill is re-cast.

  ## Instance convention

    - `val1` — skill level (1..5), drives both modifiers.

  ## Modifiers

  Long-range weapon damage taken is reduced through the status combat-families
  bridge (`ranged_damage_taken_rate`, read by `EquipmentBonuses` and applied
  only to long-range weapon hits; melee and magic are untouched):

      ranged_damage_taken_rate = -(5 + 15 * val1)

  ASPD uses the flat fixed-bonus bucket (`Stats.calculate_aspd/1`), the same
  convention as Riding's mount penalty:

      aspd = -(4 * val1)
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_defender,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:aspd],
    permanent: true,
    no_save: true

  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  def modifiers(%StatusEntry{val1: level}, _context) do
    %{ranged_damage_taken_rate: -(5 + 15 * level), aspd: -(4 * level)}
  end
end
