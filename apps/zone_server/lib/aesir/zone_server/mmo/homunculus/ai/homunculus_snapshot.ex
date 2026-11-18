defmodule Aesir.ZoneServer.Mmo.Homunculus.Ai.HomunculusSnapshot do
  @moduledoc """
  The Homunculus as one AI tick sees it.

  `busy?` is true while it casts. `target` is its retained target and
  `retaliation_target` the first candidate attacking it or its owner; both are
  `nil` unless they are among the tick's candidates. `skills` holds only the
  learned skills the AI can cast.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.SkillSnapshot
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Ref

  typedstruct enforce: true do
    field :ref, Ref.t()
    field :lifecycle, HomunculusState.lifecycle()
    field :alive?, boolean()
    field :busy?, boolean()
    field :standby?, boolean()
    field :position, {integer(), integer()}
    field :hp, non_neg_integer()
    field :max_hp, non_neg_integer()
    field :sp, non_neg_integer()
    field :max_sp, non_neg_integer()
    field :hunger, integer()
    field :food_available?, boolean()
    field :target, Ref.t() | nil, default: nil
    field :retaliation_target, Ref.t() | nil, default: nil
    field :attack_range, pos_integer()
    field :ai_config, Config.t()
    field :skills, [SkillSnapshot.t()], default: []
  end
end
