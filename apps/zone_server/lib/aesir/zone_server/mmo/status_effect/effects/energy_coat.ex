defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnergyCoat do
  @moduledoc """
  Energy Coat (SC_ENERGYCOAT).

  A self-cast buff that absorbs part of every incoming hit it covers at the cost
  of SP. Via the pre-damage `absorb_damage` hook it reduces the hit by
  `6% * (1 + per)`, where `per` is the caster's SP band: their SP as a whole
  percentage of max SP, less one, divided into 20-point intervals and clamped to
  `0..4`. The subtracted point matters at the boundaries - a caster at exactly
  40% SP sits in the band below it, not at it - and it is what makes a full SP
  bar count as the topmost band rather than overflowing past it. Each absorbed
  hit drains `(10 + 5*per) * max_sp / 1000` SP. When the remaining SP cannot pay
  that drain the status removes itself. A covered hit of zero damage is left
  alone and costs nothing. Hits it does not cover pass through unchanged.

  Renewal: the coat covers both weapon and magic damage, which makes it a general
  purpose damage sponge for a caster who can afford the SP.

  Pre-renewal: the coat covers weapon damage only. Magic passes straight through
  and costs the wearer nothing, so classic Energy Coat is purely an anti-melee
  buff.
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

  alias Aesir.Commons.GameMode

  @doc """
  Whether a hit of `dmg_type` is covered by the coat in `mode`.

  Renewal covers weapon and magic hits; classic covers weapon hits only.
  """
  @spec absorbs?(GameMode.t(), atom()) :: boolean()
  def absorbs?(_mode, :physical), do: true
  def absorbs?(mode, :magic), do: mode == :renewal
  def absorbs?(_mode, _dmg_type), do: false

  @impl true
  def absorb_damage(target, instance, %{damage: damage, dmg_type: dmg_type}, %{target: stats})
      when damage > 0 do
    if absorbs?(GameMode.mode(), dmg_type) do
      soak(target, instance, damage, stats)
    else
      {:ok, damage, instance}
    end
  end

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}

  @spec soak(tuple(), map(), non_neg_integer(), map()) ::
          :remove | {:ok, non_neg_integer(), map()}
  defp soak(target, instance, damage, stats) do
    %{sp: sp, max_sp: max_sp} = stats
    per = sp |> sp_band(max_sp) |> clamp(0, 4)
    drain = div((10 + 5 * per) * max_sp, 1_000)

    if sp < drain do
      :remove
    else
      consume_sp(target, drain)
      reduced = damage - div(damage * 6 * (1 + per), 100)
      {:ok, reduced, instance}
    end
  end

  # The percentage is taken one point short so a bar sitting exactly on a 20-point
  # boundary counts as the band below it, and a full bar lands on the top band.
  @spec sp_band(non_neg_integer(), pos_integer()) :: integer()
  defp sp_band(sp, max_sp), do: div(div(100 * sp, max_sp) - 1, 20)

  @spec clamp(integer(), integer(), integer()) :: integer()
  defp clamp(value, low, high), do: value |> max(low) |> min(high)
end
