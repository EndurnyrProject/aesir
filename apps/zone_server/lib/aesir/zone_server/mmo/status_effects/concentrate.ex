defmodule Aesir.ZoneServer.Mmo.StatusEffects.Concentrate do
  @moduledoc """
  Improve Concentration (SC_CONCENTRATE).

  Raises AGI and DEX by a percentage (val2) of the stat above its job bonus
  (val3 for AGI, val4 for DEX). Blocked by Quagmire.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_concentrate,
    properties: [:buff],
    calc_flags: [:agi, :dex],
    end_on_start: [:sc_poison, :sc_truesight],
    conflicts_with: [:sc_quagmire],
    prevented_by: [:sc_refresh, :sc_inspiration]

  @impl true
  def modifiers(instance, context) do
    stats = context.target

    %{
      agi: div((stats.agi - instance.val3) * instance.val2, 100),
      dex: div((stats.dex - instance.val4) * instance.val2, 100)
    }
  end
end
