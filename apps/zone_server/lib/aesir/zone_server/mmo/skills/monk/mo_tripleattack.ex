defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoTripleattack do
  @moduledoc """
  Raging Trifecta Blow (MO_TRIPLEATTACK).

  Its Renewal proc replaces a normal weapon attack; it is not an after-hit
  rider and therefore never stacks with the normal swing.

  Renewal procs 30% of the time at every level; pre-renewal procs 30 minus level
  percent. Both deal 100 plus 20 per level percent as one damage split into
  three equal hits.
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
end
