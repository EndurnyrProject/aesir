defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MaxOverThrust do
  @moduledoc """
  Maximum Power Thrust (SC_MAXOVERTHRUST). Adds val2 to weapon skill ratios,
  replacing ordinary Over Thrust. Val1 holds the level and val2 is 20 times it.

  Both modes end it on death, Dispel and Hermode and do not save it. Renewal
  also ends it on weapon unequip. Pre-renewal retains it on unequip and the
  shared hit stage adds 10/10,000 to the original attacker's self-break rate.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_maxoverthrust,
    no_dispel: false,
    no_clear_buff: false,
    no_save: true,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    flags: [renewal: [:remove_on_unequip_weapon], pre_renewal: []],
    end_on_start: [:sc_overthrust],
    opt3: :overthrust,
    icon: :overthrustmax

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec on_apply(Definition.target(), StatusEntry.t(), map()) :: {:ok, StatusEntry.t()}
  def on_apply(_target, instance, _context), do: {:ok, %{instance | val2: 20 * instance.val1}}

  @impl true
  @spec modifiers(StatusEntry.t(), map()) :: map()
  def modifiers(instance, _context), do: %{skill_ratio: instance.val2}
end
