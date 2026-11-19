defmodule Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas.Renewal do
  @moduledoc """
  Renewal Homunculus stats, including incremental defense and accuracy modifiers.

  Most stats carry the level stat weight, `level / 10`; HIT and the transient
  quotients read the bare stat. The weapon bounds are set once from the base
  stats and no status moves them. DEX and AGI attack-delay reductions truncate
  separately. Effective MATK is fixed at its maximum, while displayed critical
  never grants a combat chance.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas

  alias Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas
  alias Aesir.ZoneServer.Mmo.Mechanics.StatusAttack

  @impl true
  @spec derive(HomunculusFormulas.input()) :: HomunculusFormulas.result()
  def derive(%{level: level, base: base, effective: stats, modifiers: mods} = input) do
    w = div(level, 10)

    combat = %{
      atk: StatusAttack.modify(2 * level + stats.str + w, mods),
      atk_min: div(base.str + base.dex + 2 * w, 5),
      atk_max: div(base.luk + base.str + base.dex + 3 * w, 3),
      def:
        HomunculusFormulas.status_def(base.vit + w + div(level, 2) + 4 * input.skin_rank, mods) +
          div(stats.vit, 5) - div(base.vit, 5),
      soft_def:
        base.vit + w + div(base.agi + w, 2) +
          div(5 * (stats.vit - base.vit) + 2 * (stats.agi - base.agi), 10),
      mdef:
        div(base.vit + w + level + 2 * (base.int + w), 4) + div(stats.int, 5) -
          div(base.int, 5) + Map.get(mods, :mdef, 0),
      soft_mdef:
        div(base.vit + base.int + 2 * w, 2) + stats.int - base.int +
          div(stats.dex - base.dex + stats.vit - base.vit, 5),
      hit:
        max(
          level + stats.dex + 150 + div(stats.luk, 3) - div(base.luk, 3) +
            Map.get(mods, :hit, 0),
          1
        ),
      flee:
        max(
          level + stats.agi + w + div(stats.luk, 5) - div(base.luk, 5) +
            Map.get(mods, :flee, 0),
          1
        ),
      matk: stats.int + w + level + div(stats.luk + stats.int + stats.dex + 3 * w, 3)
    }

    delay = input.base_attack_delay_ms
    stat_delay = delay - div(delay * (stats.dex + w), 1_000) - div((stats.agi + w) * delay, 250)
    HomunculusFormulas.finish(combat, input, stat_delay)
  end
end
