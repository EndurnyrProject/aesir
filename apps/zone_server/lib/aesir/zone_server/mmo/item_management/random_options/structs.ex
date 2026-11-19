defmodule Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Option do
  @moduledoc """
  A random option: its id, name and bonus program.

  `program` is `nil` when the option's script uses something the equip-script
  vocabulary cannot express yet; the option then holds its slot but adds no
  bonus.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript

  @typedoc "A random option and its bonus program."
  typedstruct enforce: true do
    field :id, pos_integer()
    field :name, String.t()
    field :program, EquipScript.compiled() | nil
  end
end

defmodule Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Entry do
  @moduledoc """
  One option a random option group can roll: the option id, the inclusive
  value range, the parameter copied onto the item and the chance out of
  10,000 that a pick applies it.
  """

  use TypedStruct

  @typedoc "A rollable option of a random option group."
  typedstruct enforce: true do
    field :option_id, pos_integer()
    field :min, integer()
    field :max, integer()
    field :param, integer()
    field :chance, 0..10_000
  end
end

defmodule Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Group do
  @moduledoc """
  A random option group: the candidate options of each fixed slot, in slot
  order, and up to `max_random` further chance-gated picks from `random`.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Entry

  @typedoc "A random option group's fixed slots and random picks."
  typedstruct enforce: true do
    field :id, pos_integer()
    field :name, String.t()
    field :slots, [[Entry.t(), ...]]
    field :max_random, 0..5
    field :random, [Entry.t()]
  end
end
