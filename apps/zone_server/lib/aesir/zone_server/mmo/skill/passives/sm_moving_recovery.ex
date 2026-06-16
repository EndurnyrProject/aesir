defmodule Aesir.ZoneServer.Mmo.Skill.Passives.SmMovingRecovery do
  @moduledoc """
  HP Recovery While Moving (SM_MOVINGRECOVERY). Lets natural HP regen continue
  while the player is moving.
  """
  use Aesir.ZoneServer.Mmo.Skill.Passive, skill: :sm_movingrecovery

  @impl true
  def regen_contribution(_level, _ctx), do: %{allow_while_moving: true}
end
