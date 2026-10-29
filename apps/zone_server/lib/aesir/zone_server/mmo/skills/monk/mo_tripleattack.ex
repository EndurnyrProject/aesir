defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoTripleattack do
  @moduledoc """
  Raging Trifecta Blow (MO_TRIPLEATTACK).

  Its Renewal proc replaces a normal weapon attack; it is not an after-hit
  rider and therefore never stacks with the normal swing.

  Renewal procs 30% of the time at every level; pre-renewal procs 30 minus level
  percent. Both deal 100 plus 20 per level percent as one damage split into
  three equal hits.

  A proc keeps its user from skills for its own delay (`delay/1`), and a user
  who knows Raging Quadruple Blow gets that skill's window
  (`Combo.open_after_trifecta/3`).
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 263,
    name: :mo_tripleattack,
    display_name: "Raging Trifecta Blow",
    max_level: 10,
    target_type: :passive,
    hit_count: -3,
    damage_type: :damage

  alias Aesir.ZoneServer.Mmo.Skill.Passive
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Passive

  @impl Passive
  def attack_replacement(level, _ctx) do
    if :rand.uniform(100) <= Formulas.trifecta_activation_rate(level) do
      {:skill_attack,
       [
         skill_id: 263,
         skill_level: level,
         skill_ratio: Formulas.trifecta_ratio(level),
         hit_divisions: Formulas.trifecta_hit_count(),
         skip_crit: true
       ], :quadruple}
    else
      :normal
    end
  end

  @doc """
  The skill delay a proc arms, in ms: 1000 less 4 per AGI and 2 per DEX, then
  scaled by the equipment's delay rate (statuses such as Bragi never shorten
  it), truncated and never below 0. The rate's percentage is a single-precision
  factor, as the source computes it. A caster without player stats has the
  bare 1000 ms.
  """
  @spec delay(PlayerStats.t() | map()) :: non_neg_integer()
  def delay(%PlayerStats{} = stats) do
    agi = PlayerStats.get_effective_stat(stats, :agi)
    dex = PlayerStats.get_effective_stat(stats, :dex)
    reduction = -PlayerStats.get_equipment_modifier(stats, :delay_rate)

    (1_000 - 4 * agi - 2 * dex)
    |> scale(reduction)
    |> trunc()
    |> max(0)
  end

  def delay(_no_stats), do: 1_000

  defp scale(time, 0), do: time
  defp scale(time, reduction), do: time * single(1 - single(min(reduction, 100) / 100))

  defp single(value) do
    <<rounded::float-32>> = <<value::float-32>>
    rounded
  end
end
