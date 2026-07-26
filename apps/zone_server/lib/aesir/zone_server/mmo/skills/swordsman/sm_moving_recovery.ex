defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmMovingRecovery do
  @moduledoc """
  HP Recovery While Moving (SM_MOVINGRECOVERY). Lets natural HP regen continue
  while the player is moving.
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
