defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoTripleattack do
  @moduledoc """
  Raging Trifecta Blow (MO_TRIPLEATTACK).

  Its Renewal proc replaces a normal weapon attack; it is not an after-hit
  rider and therefore never stacks with the normal swing.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 263,
    name: :mo_tripleattack,
    display_name: "Raging Trifecta Blow",
    max_level: 10,
    target_type: :passive

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
         display_hit_count: Formulas.trifecta_hit_count(),
         skip_crit: true
       ], :quadruple}
    else
      :normal
    end
  end
end
