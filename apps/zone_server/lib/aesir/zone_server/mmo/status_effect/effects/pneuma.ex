defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Pneuma do
  @moduledoc """
  Pneuma (SC_PNEUMA).

  Blocks all long-ranged physical hits for the full duration of the status.
  Melee and magic damage pass through unchanged. No hit or shield budget —
  the status lasts until it expires naturally or is removed.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_pneuma,
    no_dispel: true,
    properties: [:buff],
    no_save: true

  @impl true
  def absorb_damage(_target, instance, %{is_short: false, dmg_type: :physical}, _context),
    do: {:ok, 0, instance}

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}
end
