defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Concentrate do
  @moduledoc """
  Improve Concentration (SC_CONCENTRATE).

  Raises AGI and DEX by a percentage (val2) of the stat above the caster's
  equipment modifier for it (val3 for AGI, val4 for DEX), so gear-granted
  points are excluded from the percentage. Blocked by Quagmire.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_concentrate,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:agi, :dex],
    end_on_start: [:sc_poison, :sc_truesight],
    conflicts_with: [:sc_quagmire],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :concentration

  @impl true
  def modifiers(instance, context) do
    stats = context.target

    %{
      agi: div((stats.agi - instance.val3) * instance.val2, 100),
      dex: div((stats.dex - instance.val4) * instance.val2, 100)
    }
  end
end
