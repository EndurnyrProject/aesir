defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Defender do
  @moduledoc """
  Defending Aura (SC_DEFENDER). A persistent toggle that trades speed for reduced
  long-range weapon damage: `val1` is the skill level (1..5).

  In the common damage stage, after any Assumptio reduction and before Blinding
  Mist, a long-range weapon hit loses `damage * (5 + 15 * level) / 100`
  (the removed amount is truncated). The walk delay is floored at 200 ms per cell
  in both modes. Renewal loses 25 minus 5 per level flat attack speed;
  pre-renewal loses the same figure as a percentage rate.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_defender,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
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
    case GameMode.mode() do
      :renewal -> %{walk_speed_floor: 200, aspd: -(25 - 5 * level)}
      :pre_renewal -> %{walk_speed_floor: 200, aspd_rate: -(25 - 5 * level)}
    end
  end

  @impl true
  def absorb_damage(_target, %StatusEntry{val1: level} = instance, hit, _context) do
    case hit do
      %{damage: damage, dmg_type: :physical, is_short: false} ->
        {:ok, damage - div(damage * (5 + 15 * level), 100), instance}

      %{damage: damage} ->
        {:ok, damage, instance}
    end
  end
end
