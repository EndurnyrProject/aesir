defmodule Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas.PreRenewal do
  @moduledoc """
  Classic Homunculus stats with unshifted accuracy and percentage hard defenses.

  Initial hard defenses precede passives. The weapon range is base DEX to base
  STR plus level, each moved only by status weapon ATK and held to `0..65_535`;
  an excessive DEX collapses it to its maximum. The DEX/AGI attack-delay
  reduction uses one combined division. Effective MATK is fixed at its maximum.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas

  alias Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas
  alias Aesir.ZoneServer.Mmo.Mechanics.StatusAttack

  @impl true
  @spec derive(HomunculusFormulas.input()) :: HomunculusFormulas.result()
  def derive(%{level: level, raw: raw, base: base, effective: stats, modifiers: mods} = input) do
    weapon_min = HomunculusFormulas.status_watk(base.dex, mods)
    weapon_max = HomunculusFormulas.status_watk(base.str + level, mods)
    hard_def = (div(level, 10) + div(raw.vit, 5)) |> max(0) |> min(99)
    hard_mdef = (div(level, 10) + div(raw.int, 5)) |> max(0) |> min(99)

    combat = %{
      atk: StatusAttack.modify(stats.str + div(stats.str, 10) * div(stats.str, 10), mods),
      atk_min: min(weapon_min, weapon_max),
      atk_max: weapon_max,
      def:
        HomunculusFormulas.status_def(hard_def + 4 * input.skin_rank, mods) +
          div(stats.vit, 5) - div(base.vit, 5),
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
