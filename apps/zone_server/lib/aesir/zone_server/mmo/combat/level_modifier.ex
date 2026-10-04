defmodule Aesir.ZoneServer.Mmo.Combat.LevelModifier do
  @moduledoc """
  The renewal base-level damage modifier some skills apply to their ratio: the
  ratio is multiplied by `base_level / 100`, but only for a caster above base
  level 99. Monsters use their level. Callers apply it in renewal only.
  """

  @doc "Scales `ratio` by `base_level / 100` when `base_level` exceeds 99."
  @spec skill_ratio(integer(), non_neg_integer()) :: integer()
  def skill_ratio(ratio, base_level) when base_level > 99, do: div(ratio * base_level, 100)
  def skill_ratio(ratio, _base_level), do: ratio
end
