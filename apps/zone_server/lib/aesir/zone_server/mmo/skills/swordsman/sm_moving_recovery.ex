defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmMovingRecovery do
  @moduledoc """
  HP Recovery While Moving (SM_MOVINGRECOVERY). A quest-granted passive that
  lets HP regeneration keep running while the player walks.

  Renewal: without it, both the base HP tick and the skill HP tick are
  suppressed while moving; with it, they keep firing at their ordinary rate.
  The skill has a single level and grants nothing else.

  Pre-renewal: identical, single-level, same effect on the same two HP
  channels. The passive is not era-gated in any way.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 144,
    name: :sm_movingrecovery,
    display_name: "HP Recovery While Moving",
    max_level: 1,
    target_type: :passive,
    quest_skill: true,
    quest_owner_job: :swordman

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def regen_contribution(_level, _ctx), do: %{allow_while_moving: true}
end
