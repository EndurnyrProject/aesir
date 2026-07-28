defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaMusicallesson do
  @moduledoc """
  Musical Lesson (BA_MUSICALLESSON).

  Grants instrument weapon ATK, MaxSP rate, and the status-presence-dependent
  ASPD contribution of the Renewal passive.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 315,
    name: :ba_musicallesson,
    display_name: "Musical Lesson",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: :musical}), do: 3 * level
  def atk_bonus(_level, _ctx), do: 0

  @impl Passive
  def max_sp_rate_bonus(level, _ctx), do: level

  @impl Passive
  def aspd_bonus(level, %{statuses_active?: true}), do: level
  def aspd_bonus(_level, _ctx), do: 0
end
