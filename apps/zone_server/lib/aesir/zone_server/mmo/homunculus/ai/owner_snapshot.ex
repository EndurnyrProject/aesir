defmodule Aesir.ZoneServer.Mmo.Homunculus.Ai.OwnerSnapshot do
  @moduledoc """
  The owner as one Homunculus AI tick sees it.

  `target` is the owner's combat target when it is one of the tick's candidates,
  otherwise `nil`.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Unit.Ref

  typedstruct enforce: true do
    field :ref, Ref.t()
    field :position, {integer(), integer()}
    field :hp, non_neg_integer()
    field :max_hp, pos_integer()
    field :alive?, boolean()
    field :target, Ref.t() | nil, default: nil
  end
end
