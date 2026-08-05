defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfDouble do
  @moduledoc """
  Double Attack (TF_DOUBLE). Dagger-only chance to deliver the basic attack twice.

  A dagger has a `7 * level`% chance to double the hit and gain `+level` HIT
  for that proc. Unlike Sword Mastery's flat `atk_bonus`, the multi-hit here is
  chance-based, so it rides `Skill.Passive.attack_proc/2`'s `:chance` key.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 48,
    name: :tf_double,
    display_name: "Double Attack",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def attack_proc(level, %{weapon_type: :dagger}),
    do: %{multi_hit: 2, chance: 7 * level, hit_bonus: level}

  def attack_proc(_level, _ctx), do: %{}

  @impl Passive
  def katar_secondary_rate(level, %{weapon_type: :katar}), do: 1 + 2 * level
  def katar_secondary_rate(_level, _ctx), do: 0
end
