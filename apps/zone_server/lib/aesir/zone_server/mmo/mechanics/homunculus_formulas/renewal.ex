defmodule Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas.Renewal do
  @moduledoc """
  Renewal Homunculus stats, including incremental defense and accuracy modifiers.

  DEX and AGI attack-delay reductions truncate separately. Effective MATK is
  fixed at its maximum, while displayed critical never grants a combat chance.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas

  alias Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas

  @impl true
  @spec derive(HomunculusFormulas.input()) :: HomunculusFormulas.result()
  def derive(%{level: level, base: base, effective: stats, modifiers: mods} = input) do
    combat = %{
      atk: 2 * level + stats.str,
      atk_min: div(stats.str + stats.dex, 5),
      atk_max: div(stats.luk + stats.str + stats.dex, 3),
      def:
        base.vit + div(level, 2) + 4 * input.skin_rank + div(stats.vit, 5) -
          div(base.vit, 5) + Map.get(mods, :def, 0),
      soft_def:
        base.vit + div(base.agi, 2) +
          div(5 * (stats.vit - base.vit) + 2 * (stats.agi - base.agi), 10),
      mdef:
        div(base.vit + level + 2 * base.int, 4) + div(stats.int, 5) -
          div(base.int, 5) + Map.get(mods, :mdef, 0),
      soft_mdef:
        div(base.vit + base.int, 2) + stats.int - base.int +
          div(stats.dex - base.dex + stats.vit - base.vit, 5),
      hit:
        max(
          level + stats.dex + 150 + div(stats.luk, 3) - div(base.luk, 3) +
            Map.get(mods, :hit, 0),
          1
        ),
      flee:
        max(
          level + stats.agi + div(stats.luk, 5) - div(base.luk, 5) +
            Map.get(mods, :flee, 0),
          1
        ),
      matk: stats.int + level + div(stats.luk + stats.int + stats.dex, 3)
    }

    delay = input.base_attack_delay_ms
    stat_delay = delay - div(delay * stats.dex, 1_000) - div(stats.agi * delay, 250)
    HomunculusFormulas.finish(combat, input, stat_delay)
  end
end
