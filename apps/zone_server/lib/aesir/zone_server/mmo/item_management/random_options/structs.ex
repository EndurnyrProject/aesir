defmodule Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Option do
  @moduledoc """
  A random option: its id, name and bonus program.

  `program` is `nil` when the option's script uses something the equip-script
  vocabulary cannot express yet; the option then holds its slot but adds no
  bonus.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript

  @enforce_keys [:id, :name, :program]
  defstruct [:id, :name, :program]

  @type t() :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          program: EquipScript.program() | nil
        }
end

defmodule Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Entry do
  @moduledoc """
  One option a random option group can roll: the option id, the inclusive
  value range, the parameter copied onto the item and the chance out of
  10,000 that a pick applies it.
  """

  @enforce_keys [:option_id, :min, :max, :param, :chance]
  defstruct [:option_id, :min, :max, :param, :chance]

  @type t() :: %__MODULE__{
          option_id: pos_integer(),
          min: integer(),
          max: integer(),
          param: integer(),
          chance: 0..10_000
        }
end

defmodule Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Group do
  @moduledoc """
  A random option group: the candidate options of each fixed slot, in slot
  order, and up to `max_random` further chance-gated picks from `random`.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Entry

  @enforce_keys [:id, :name, :slots, :max_random, :random]
  defstruct [:id, :name, :slots, :max_random, :random]

  @type t() :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          slots: [[Entry.t(), ...]],
          max_random: 0..5,
          random: [Entry.t()]
        }
end
