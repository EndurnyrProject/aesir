defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Defender do
  @moduledoc """
  Defending Aura (SC_DEFENDER). A persistent toggle that trades speed for reduced
  long-range weapon damage: `val1` is the skill level (1..5).

  Long-range weapon damage taken drops by 5 plus 15 per level percent and the walk
  delay is floored at 200 ms per cell in both modes. Renewal loses 25 minus 5 per
  level flat attack speed; pre-renewal loses the same figure as a percentage rate.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_defender,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:aspd, :aspd_rate, :speed],
    flags: [:remove_on_unequip_shield],
    icon: :defender,
    permanent: true,
    no_save: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  def modifiers(%StatusEntry{val1: level}, _context) do
    base = %{ranged_damage_taken_rate: -(5 + 15 * level), walk_speed_floor: 200}

    case GameMode.mode() do
      :renewal -> Map.put(base, :aspd, -(25 - 5 * level))
      :pre_renewal -> Map.put(base, :aspd_rate, -(25 - 5 * level))
    end
  end
end
