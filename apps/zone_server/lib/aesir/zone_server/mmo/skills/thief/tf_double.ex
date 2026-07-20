defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfDouble do
  @moduledoc """
  Double Attack (TF_DOUBLE). Dagger-only chance to deliver the basic attack twice.

  rAthena: `7 * level`% chance to double the hit, dagger only; also adds `+level`
  HIT while a dagger is equipped. Unlike Sword Mastery's flat `atk_bonus`, the
  multi-hit here is chance-based, so it rides `Skill.Passive.attack_proc/2`'s
  `:chance` key (rolled by `Combat.attack_hits/1`) rather than firing every hit.
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
  def attack_proc(level, %{weapon_type: :dagger}), do: %{multi_hit: 2, chance: 7 * level}
  def attack_proc(_level, _ctx), do: %{}

  @impl Passive
  def hit_bonus(level, %{weapon_type: :dagger}), do: level
  def hit_bonus(_level, _ctx), do: 0
end
