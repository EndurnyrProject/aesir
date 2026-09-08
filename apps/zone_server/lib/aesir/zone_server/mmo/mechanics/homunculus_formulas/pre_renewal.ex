defmodule Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas.PreRenewal do
  @moduledoc """
  Classic Homunculus stats with unshifted accuracy and percentage hard defenses.

  Initial hard defenses precede passives. The DEX/AGI attack-delay reduction
  uses one combined division, and an excessive DEX collapses the weapon range
  to its maximum. Effective MATK is fixed at its maximum.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas

  alias Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas

  @impl true
  @spec derive(HomunculusFormulas.input()) :: HomunculusFormulas.result()
  def derive(%{level: level, raw: raw, base: base, effective: stats, modifiers: mods} = input) do
    weapon_max = stats.str + level
    hard_def = (div(level, 10) + div(raw.vit, 5)) |> max(0) |> min(99)
    hard_mdef = (div(level, 10) + div(raw.int, 5)) |> max(0) |> min(99)

    combat = %{
      atk: stats.str + div(stats.str, 10) * div(stats.str, 10),
      atk_min: min(stats.dex, weapon_max),
      atk_max: weapon_max,
      def:
        hard_def + 4 * input.skin_rank + div(stats.vit, 5) - div(base.vit, 5) +
          Map.get(mods, :def, 0),
      soft_def: max(stats.vit, 1),
      mdef: hard_mdef + div(stats.int, 5) - div(base.int, 5) + Map.get(mods, :mdef, 0),
      soft_mdef:
        base.int + div(base.vit, 2) + stats.int - base.int + div(stats.vit - base.vit, 2),
      hit: max(level + stats.dex + Map.get(mods, :hit, 0), 1),
      flee: max(level + stats.agi + Map.get(mods, :flee, 0), 1),
      matk: stats.int + div(stats.int, 5) * div(stats.int, 5)
    }

    stat_delay = div((1_000 - 4 * stats.agi - stats.dex) * input.base_attack_delay_ms, 1_000)
    HomunculusFormulas.finish(combat, input, stat_delay)
  end
end
