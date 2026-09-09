defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfDouble do
  @moduledoc """
  Double Attack (TF_DOUBLE). Dagger-only chance to deliver the basic attack twice.

  A dagger has a `7 * level`% chance to double the hit and gain `+level` HIT
  for that proc. Unlike Sword Mastery's flat `atk_bonus`, the multi-hit here is
  chance-based, so it rides `Skill.Passive.attack_proc/2`'s `:chance` key.

  Renewal: a dagger auto-attack has a 7% per level chance to strike twice with +1 HIT per level on the double. Pre-renewal: 5% per level. Both modes: a katar's off-hand strike gains 1% plus 2% per level.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 48,
    name: :tf_double,
    display_name: "Double Attack",
    max_level: 10,
    target_type: :passive,
    hit_count: 2

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def attack_proc(level, %{weapon_type: :dagger}),
    do: %{multi_hit: 2, chance: chance_per_level() * level, hit_bonus: level}

  def attack_proc(_level, _ctx), do: %{}

  defp chance_per_level do
    case GameMode.mode() do
      :renewal -> 7
      :pre_renewal -> 5
    end
  end

  @impl Passive
  def katar_secondary_rate(level, %{weapon_type: :katar}), do: 1 + 2 * level
  def katar_secondary_rate(_level, _ctx), do: 0
end
