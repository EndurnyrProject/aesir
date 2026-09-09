defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnRiding do
  @moduledoc """
  Peco Peco Riding (KN_RIDING). Grants a Knight the ability to mount a
  Peco-Peco.

  Purely a gate: learning this skill unlocks the `@mount`/dismount action
  elsewhere in the movement and stats pipeline. It contributes no passive
  stat bonuses of its own; the mounted movement speed and attack-speed
  penalty are applied by the riding status effect, whose penalty is in turn
  reduced by `KnCavaliermastery`.

  Renewal and pre-renewal agree: riding adds 10000 carry weight, moves 25% faster, and costs attack speed that Cavalier Mastery buys back.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 63,
    name: :kn_riding,
    display_name: "Peco Peco Riding",
    max_level: 1,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def max_weight_bonus(_level, %{riding: true}), do: 10_000
  def max_weight_bonus(_level, _ctx), do: 0
end
