defmodule Aesir.ZoneServer.Mmo.MobManagement.MobDrop do
  @moduledoc """
  A single item that can be dropped by a mob.
  """

  use TypedStruct

  typedstruct do
    @typedoc "A drop entry in a monster definition."
    field :item, String.t(), enforce: true
    field :rate, integer(), enforce: true
    field :steal_protected, boolean(), default: false
    field :random_option_group, String.t()
  end
end
