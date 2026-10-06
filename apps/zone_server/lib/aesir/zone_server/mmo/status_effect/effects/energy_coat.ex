defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnergyCoat do
  @moduledoc """
  Energy Coat (SC_ENERGYCOAT).

  A self-cast buff that absorbs part of every incoming hit it covers at the cost
  of SP. In the common damage stage, after Blinding Mist and before Mental
  Strength, it charges `(10 + 5*per) * max_sp / 1000` SP and then removes
  `damage * 6 * (1 + per) / 100` (truncated) from the hit. `per` is the holder's
  SP band: their SP as a whole percentage of max SP, less one, divided into
  20-point intervals (truncated toward zero). The subtracted point matters at
  the boundaries - a holder at exactly 40% SP sits in the band below it - and it
  makes a full SP bar the topmost band.

  A charge the holder cannot pay, or one that rounds to zero SP, takes nothing
  and ends the status, but the hit is still reduced. Cart Termination is never
  covered; other hits it does not cover pass through unchanged.

  Renewal: the coat covers both weapon and magic damage. Pre-renewal: weapon
  damage only.
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

  @cart_termination 485

  @impl true
  def absorb_damage(target, instance, %{damage: damage, dmg_type: dmg_type} = hit, %{
        target: stats
      }) do
    if absorbs?(GameMode.mode(), dmg_type) and Map.get(hit, :skill_id) != @cart_termination do
      soak(target, instance, damage, stats)
    else
      {:ok, damage, instance}
    end
  end

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}

  @spec soak(tuple(), map(), integer(), map()) ::
          {:remove, integer()} | {:ok, integer(), map()}
  defp soak(target, instance, damage, %{sp: sp, max_sp: max_sp}) do
    per = div(div(100 * sp, max_sp) - 1, 20)
    charge = div((10 + 5 * per) * max_sp, 1_000)
    reduced = damage - div(damage * 6 * (1 + per), 100)

    if charge > 0 and charge <= sp do
      consume_sp(target, charge)
      {:ok, reduced, instance}
    else
      {:remove, reduced}
    end
  end
end
