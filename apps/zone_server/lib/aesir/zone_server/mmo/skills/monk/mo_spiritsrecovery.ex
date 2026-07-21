defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoSpiritsrecovery do
  @moduledoc """
  Spiritual Cadence (MO_SPIRITSRECOVERY). Adds HP and SP recovery while sitting.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 260,
    name: :mo_spiritsrecovery,
    display_name: "Spiritual Cadence",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas

  @behaviour Passive

  @impl Passive
  def regen_contribution(level, %{max_hp: max_hp, max_sp: max_sp}) do
    {sitting_hp_regen, sitting_sp_regen} =
      Formulas.spiritual_cadence_regeneration(level, max_hp, max_sp)

    %{sitting_hp_regen: sitting_hp_regen, sitting_sp_regen: sitting_sp_regen}
  end
end
