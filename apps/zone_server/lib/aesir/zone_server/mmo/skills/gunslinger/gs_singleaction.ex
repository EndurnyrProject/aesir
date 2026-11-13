defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsSingleaction do
  @moduledoc """
  Single Action grants gun users two HIT per level. Renewal adds a fixed ASPD
  contribution of half the level rounded up; pre-renewal adds that many percent
  to the ASPD rate instead.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 509,
    name: :gs_singleaction,
    display_name: "Single Action",
    max_level: 10,
    target_type: :passive,
    damage_kind: :none,
    damage_type: :damage

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
  @guns [:revolver, :rifle, :gatling, :shotgun, :grenade]

  @impl Passive
  def hit_bonus(level, %{weapon_type: weapon}) when weapon in @guns, do: 2 * level
  def hit_bonus(_level, _ctx), do: 0

  @impl Passive
  def aspd_bonus(level, %{weapon_type: weapon}) when weapon in @guns do
    if GameMode.mode() == :renewal, do: div(level + 1, 2), else: 0
  end

  def aspd_bonus(_level, _ctx), do: 0

  @impl Passive
  def aspd_rate_bonus(level, %{weapon_type: weapon}) when weapon in @guns do
    if GameMode.mode() == :pre_renewal, do: div(level + 1, 2), else: 0
  end

  def aspd_rate_bonus(_level, _ctx), do: 0
end
