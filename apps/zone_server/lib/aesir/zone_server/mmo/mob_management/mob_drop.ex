defmodule Aesir.ZoneServer.Mmo.MobManagement.MobDrop do
  @moduledoc """
  TypedStruct for mob drop items.
  Represents a single item that can be dropped by a mob.
  """
  use TypedStruct

  typedstruct do
    field :item, String.t(), enforce: true
    field :rate, integer(), enforce: true
    field :steal_protected, boolean(), default: false
    field :random_option_group, String.t()
  end
end
