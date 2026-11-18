defmodule Aesir.ZoneServer.Mmo.Homunculus.Ai.SkillSnapshot do
  @moduledoc """
  A learned Homunculus skill as one AI tick sees it.

  `target` is who the AI casts it on. `sp_cost` is the cost at the learned
  level, already resolved for skills that spend all remaining SP.
  """

  use TypedStruct

  typedstruct enforce: true do
    field :id, pos_integer()
    field :level, pos_integer()
    field :target, :self | :owner | :enemy
    field :sp_cost, non_neg_integer()
    field :cooldown_ready?, boolean()
  end
end
