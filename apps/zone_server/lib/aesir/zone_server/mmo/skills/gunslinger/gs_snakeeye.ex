defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsSnakeeye do
  @moduledoc """
  Snake Eye grants gun users one HIT and one cell of attack range per level.
  Its separate skill-range bonus is handled by the skill range calculation.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 510,
    name: :gs_snakeeye,
    display_name: "Snake Eye",
    max_level: 10,
    target_type: :passive,
    damage_kind: :none,
    damage_type: :damage

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
  @guns [:revolver, :rifle, :gatling, :shotgun, :grenade]

  @impl Passive
  def hit_bonus(level, %{weapon_type: weapon}) when weapon in @guns, do: level
  def hit_bonus(_level, _ctx), do: 0

  @impl Passive
  def range_bonus(level, %{weapon_type: weapon}) when weapon in @guns, do: level
  def range_bonus(_level, _ctx), do: 0
end
