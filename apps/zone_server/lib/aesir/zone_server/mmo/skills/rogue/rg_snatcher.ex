defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgSnatcher do
  @moduledoc """
  Gank (RG_SNATCHER) adds a chance to steal an item on a landed normal attack.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 210,
    name: :rg_snatcher,
    display_name: "Gank",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  @spec steal_proc(pos_integer(), Passive.ctx()) :: %{chance_permille: non_neg_integer()}
  def steal_proc(level, %{learned_skills: learned_skills}) do
    %{chance_permille: level * 15 + 55 + Map.get(learned_skills, 50, 0) * 10}
  end
end
