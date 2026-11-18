defmodule Aesir.ZoneServer.Mmo.Homunculus.Ai.CandidateSnapshot do
  @moduledoc """
  A nearby mob the Homunculus AI may target on one tick.

  `claim_root` is the player owning the mob's first reward claim, or `nil` when
  the mob is unclaimed.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Unit.Ref

  typedstruct enforce: true do
    field :ref, Ref.t()
    field :position, {integer(), integer()}
    field :hp, non_neg_integer()
    field :max_hp, pos_integer()
    field :class_id, pos_integer()
    field :boss?, boolean()
    field :claim_root, Ref.t() | nil, default: nil
  end
end
