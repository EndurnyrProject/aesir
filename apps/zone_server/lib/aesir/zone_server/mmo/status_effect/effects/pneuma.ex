defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Pneuma do
  @moduledoc """
  Pneuma (SC_PNEUMA).

  Blocks every long-range non-magic hit (weapon or misc) that still carries
  damage after Kyrie Eleison and Safety Wall, for the full duration of the
  status. Melee and magic damage pass through unchanged. No hit or shield
  budget: the status lasts until it expires or is removed.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_pneuma,
    no_dispel: true,
    properties: [:buff],
    no_save: true

  @impl true
  def absorb_damage(_target, instance, %{is_short: false, dmg_type: dmg_type}, _context)
      when dmg_type != :magic,
      do: {:ok, 0, instance}

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}
end
