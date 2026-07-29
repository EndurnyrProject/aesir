defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcDancinglesson do
  @moduledoc """
  Dancing Lesson (DC_DANCINGLESSON).

  Grants whip weapon ATK, critical, and SP regeneration.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 323,
    name: :dc_dancinglesson,
    display_name: "Dancing Lesson",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: :whip}), do: 3 * level
  def atk_bonus(_level, _ctx), do: 0

  @impl Passive
  def critical_bonus(level, _ctx), do: level

  @impl Passive
  def regen_contribution(level, _ctx), do: %{skill_sp_regen: level}
end
