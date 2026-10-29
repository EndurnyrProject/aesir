defmodule Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscKatar do
  @moduledoc """
  Advanced Katar Mastery raises a player's damage with a katar by 10 percent plus
  2 percent per level.

  Renewal applies it to every physical hit, normal attacks and skills alike,
  right after the skill ratio and its constant addition, before RES and DEF; the
  katar's second hit inherits it. Classic applies it as one more attack card
  percentage on melee hits, so a skill that ignores attack cards (Soul Destroyer,
  Meteor Assault) or an arrow attack does not take it.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 376,
    name: :asc_katar,
    display_name: "Advanced Katar Mastery",
    max_level: 5,
    target_type: :passive,
    damage_type: :no_damage

  @doc "The percent damage bonus at `level`; 0 when not learned."
  @spec damage_rate(non_neg_integer()) :: non_neg_integer()
  def damage_rate(0), do: 0
  def damage_rate(level), do: 10 + 2 * level
end
