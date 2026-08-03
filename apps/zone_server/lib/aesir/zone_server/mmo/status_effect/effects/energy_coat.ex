defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnergyCoat do
  @moduledoc """
  Energy Coat (SC_ENERGYCOAT).

  A self-cast buff that absorbs part of every incoming weapon or magic hit at the
  cost of SP. Via the pre-damage `absorb_damage` hook it reduces the hit by
  `6% * (1 + per)` where `per = clamp(div(SP%, 20), 0, 4)` and `SP%` is the
  caster's current SP as a percentage of max SP. Each absorbed hit drains
  `(10 + 5*per) * max_sp / 1000` SP. When the remaining SP cannot pay that drain
  the status removes itself. Non weapon/magic hits pass through unchanged.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_energycoat,
    no_dispel: false,
    properties: [:buff],
    target_types: [:player],
    duration: 300_000,
    icon: :energycoat,
    opt3: :energycoat

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers, only: [consume_sp: 2]

  @absorbed_types [:physical, :magic]

  @impl true
  def absorb_damage(target, instance, %{damage: damage, dmg_type: dmg_type}, %{target: stats})
      when dmg_type in @absorbed_types do
    %{sp: sp, max_sp: max_sp} = stats
    per = sp |> sp_percent(max_sp) |> div(20) |> clamp(0, 4)
    drain = div((10 + 5 * per) * max_sp, 1_000)

    if sp < drain do
      :remove
    else
      consume_sp(target, drain)
      reduced = damage - div(damage * 6 * (1 + per), 100)
      {:ok, reduced, instance}
    end
  end

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}

  @spec sp_percent(non_neg_integer(), pos_integer()) :: non_neg_integer()
  defp sp_percent(sp, max_sp), do: div(100 * sp, max_sp)

  @spec clamp(integer(), integer(), integer()) :: integer()
  defp clamp(value, low, high), do: value |> max(low) |> min(high)
end
